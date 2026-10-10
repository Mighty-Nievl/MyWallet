import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/auth_service.dart';
import '../../data/connectivity.dart';
import '../../data/household.dart';
import '../../data/providers.dart';
import '../../data/sync_service.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Sub-halaman Keluarga (Fase 1, v1.17): login Google + buat/gabung rumah
/// tangga + kode invite. Opt-in — tanpa login = offline murni.
///
/// STEP 4 — bahasa presentasi: [BackHeader] + [SettingsGroup] +
/// [SettingRow]; font-scale ikut via [AppType].
///
/// v1.17.1 UX: status personal = hero empty-state (manfaat + tombol
/// Google besar), error tampil INLINE (kartu error + tombol Coba lagi),
/// bukan snackbar kontras-rendah yang gampang kelewat.
class FamilySettingsPage extends ConsumerStatefulWidget {
  const FamilySettingsPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<FamilySettingsPage> createState() =>
      _FamilySettingsPageState();
}

class _FamilySettingsPageState extends ConsumerState<FamilySettingsPage> {
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _q = '';
  bool _busy = false;
  bool _showCreate = false;
  bool _showJoin = false;

  /// Error terakhir + aksi ulangannya — ditampilkan INLINE di layar
  /// (bukan snackbar) agar kontras + ada tombol Coba lagi.
  /// [_rawError] = string exception asli untuk diagnostik (long-press
  /// banner → salin). Pesan ramah tetap yang tampil utama.
  String? _errorMsg;
  String? _rawError;
  Future<FamilySession> Function()? _retryJob;

  @override
  void initState() {
    super.initState();
    _q = widget.initialQuery.trim().toLowerCase();
    if (_q.isNotEmpty) _searchCtrl.text = widget.initialQuery;
    // Validasi live: tombol Buat/Gabung aktif-nonaktif mengikuti isi field.
    _nameCtrl.addListener(_onFormChanged);
    _codeCtrl.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFormChanged);
    _codeCtrl.removeListener(_onFormChanged);
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool _match(String title, String subtitle,
      [List<String> keys = const []]) {
    if (_q.isEmpty) return true;
    final hay = '$title $subtitle ${keys.join(' ')}'.toLowerCase();
    return hay.contains(_q);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// Bagikan kode invite via share sheet (WA, dll). Kode diambil dari
  /// server (timeout di service); gagal = error inline + Coba lagi hilang.
  Future<void> _shareInvite(AuthService svc, FamilySession s) async {
    final code = await svc.activeInviteCode();
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _errorMsg = 'Kode kedaluwarsa — putar kode baru di bawah.';
        _retryJob = null;
      });
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: inviteShareText(code, s.householdName),
          subject: 'Kode gabung MyWallet',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: code));
      _snack('Share gagal — kode $code disalin.');
    }
  }

  /// Keluar rumah tangga DENGAN pengaman (v1.19.1): dialog konfirmasi +
  /// peringatan ekstra bila pengelola-terakhir. Tanpa ini sekali tap
  /// langsung pergi — temuan ReWin: "keluar dari Rumah tangga belum ada
  /// pengamannya". Keluar SELALU boleh (termasuk pengelola terakhir —
  /// diblokir = jebakan tanpa jalan keluar in-app); dialog yang beri
  /// peringatan "rumah jadi kosong" agar keputusan sadar.
  Future<void> _confirmLeaveHousehold(AuthService svc, FamilySession s) async {
    if (_busy) return;
    // Cek komposisi anggota dulu (butuh online; offline = tolak ramah).
    List<HouseholdMember> members = const [];
    try {
      members = await svc.fetchMembers();
    } catch (_) {
      members = const [];
    }
    if (!mounted) return;
    if (members.isEmpty) {
      setState(() {
        _errorMsg =
            'Tidak bisa cek anggota saat offline — sambungkan internet dulu biar tidak salah keluar.';
        _rawError = null;
        _retryJob = null;
      });
      return;
    }
    final me = members.where((m) => m.uid == s.uid).toList();
    final iAmOwner =
        me.isNotEmpty ? me.first.isOwner : await svc.isOwner();
    if (!mounted) return;
    final ownerCount = members.where((m) => m.isOwner).length;
    final lastOwner = iAmOwner && ownerCount <= 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar rumah tangga?'),
        content: Text(
          'Kamu akan keluar dari ${s.householdName ?? 'rumah'}. '
          'Data lokal HP ini tetap aman, sync berhenti. '
          'Untuk gabung lagi butuh kode invite baru.'
          '${lastOwner ? '\n\nPERHATIAN: kamu pengelola satu-satunya — rumah jadi kosong tanpa pengelola.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            child: Text(lastOwner ? 'Tetap keluar' : 'Ya, keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(svc.leaveHousehold);
  }

  Future<void> _run(Future<FamilySession> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
      _rawError = null;
      _retryJob = null;
    });
    try {
      await job();
      if (mounted) {
        setState(() {
          _showCreate = false;
          _showJoin = false;
        });
      }
    } on FamilyException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.message;
          // FamilyException.message sudah ramah — mentahnya = pesan tsb.
          _rawError = e.toString();
          _retryJob = job;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Gagal — coba lagi.';
          _rawError = e.toString();
          _retryJob = job;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(familySessionProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: 'Keluarga'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  96,
                ),
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari di Keluarga…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _q.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _q = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  session.when(
                    loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: AppSkeleton(lines: 3)),
                    error: (_, _) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'Gagal memuat sesi — mode pribadi (offline).')),
                    data: (s) => _body(s, scheme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu error inline: ikon + pesan kontras-tinggi + tombol Coba lagi.
  /// Muncul tepat di atas konten yang gagal (bukan snackbar bawah).
  /// Long-press banner = salin detail mentah (diagnostik v1.18.2): user
  /// kirim ke Rezal, debat "sinyal vs server" selesai pakai data.
  Widget _errorCard() {
    final scheme = Theme.of(context).colorScheme;
    final retry = _retryJob;
    return GestureDetector(
      onLongPress: () async {
        final raw = _rawError;
        if (raw == null || raw.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: raw));
        _snack('Detail error disalin — kirim ke Rezal.');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    _errorMsg ?? 'Gagal.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (retry != null)
                  TextButton(
                    onPressed:
                        _busy ? null : () => _run(retry),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onErrorContainer,
                    ),
                    child: const Text('Coba lagi'),
                  ),
              ],
            ),
            if (_rawError != null && _rawError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tahan untuk salin detail teknis.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(FamilySession s, ColorScheme scheme) {
    final svc = ref.read(authServiceProvider);
    // Sinyal preemptif: tombol jaringan mati saat RADIO mati (mode
    // pesawat / WiFi+data mati semua). WiFi nyala tapi internet zonk
    // (0,76 KB/S) tetap lolos — kebenaran diputus service via timeout
    // 20 dtk + pesan ramah (lapis kedua).
    final offline = ref.watch(isOfflineProvider).value ?? false;
    switch (s.status) {
      case FamilyStatus.loading:
        return const Padding(
            padding: EdgeInsets.all(16), child: AppSkeleton(lines: 3));
      case FamilyStatus.personal:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMsg != null) _errorCard(),
            if (_match('login', 'google', const ['login', 'masuk']))
              _personalHero(svc),
          ],
        );
      case FamilyStatus.signedIn:
        return Column(
          children: [
            if (_errorMsg != null) _errorCard(),
            if (_match('akun', 'keluar', const ['email', 'profil']))
              SettingsGroup(
                title: 'Akun',
                children: [
                  SettingRow(
                    icon: Icons.account_circle_outlined,
                    title: s.displayName ?? s.email ?? 'Akun Google',
                    subtitle: s.email ?? 'Masuk — belum gabung rumah tangga',
                    trailing: TextButton(
                      onPressed: _busy ? null : () => _run(svc.signOut),
                      child: const Text('Keluar'),
                    ),
                  ),
                  // Diagnostik v1.18.2: bedakan "jalur Auth OK" vs
                  // "jalur Firestore buntu" tanpa tebak-tebakan sinyal.
                  SettingRow(
                    icon: Icons.network_check_outlined,
                    title: 'Tes koneksi',
                    subtitle:
                        'Cek Auth + Firestore, salin hasil ke Rezal',
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final r = await svc.connectionTest();
                              if (!mounted) return;
                              setState(() {
                                _rawError = r;
                                _errorMsg = null;
                                _retryJob = null;
                              });
                              await Clipboard.setData(
                                  ClipboardData(text: r));
                              _snack(
                                  'Hasil tes disalin — kirim ke Rezal.');
                            } finally {
                              if (mounted) {
                                setState(() => _busy = false);
                              }
                            }
                          },
                  ),
                  // Hasil tes terakhir (bila ada): tampil inline agar
                  // bisa dibaca + disalin manual bila perlu.
                  if (_rawError != null &&
                      _errorMsg == null &&
                      _rawError!.startsWith('Auth:'))
                    SettingRow(
                      icon: Icons.terminal_outlined,
                      title: 'Hasil tes',
                      subtitle: _rawError,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sectionGap),
            if (_match('buat', 'baru', const ['household', 'rumah']))
              SettingsGroup(
                title: 'Rumah tangga',
                children: [
                  SettingRow(
                    icon: Icons.group_add_outlined,
                    title: 'Buat rumah tangga',
                    subtitle: 'Jadi pengelola + dapat kode invite',
                    onTap: _busy
                        ? null
                        : () => setState(() {
                              _showCreate = !_showCreate;
                              _showJoin = false;
                            }),
                  ),
                  if (_showCreate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            maxLength: householdNameMaxLength,
                            decoration: InputDecoration(
                              labelText: 'Nama rumah tangga',
                              hintText: 'cth. Keluarga Rezal',
                              counterText:
                                  '${_nameCtrl.text.trim().length}/$householdNameMaxLength',
                              errorText: _nameCtrl.text.isEmpty
                                  ? null
                                  : validateHouseholdName(_nameCtrl.text),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: (_busy ||
                                    offline ||
                                    validateHouseholdName(_nameCtrl.text) !=
                                        null)
                                ? null
                                : () => _run(() => svc.createHousehold(
                                    _nameCtrl.text)),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(offline ? 'Buat (tanpa sinyal)' : 'Buat'),
                          ),
                          if (offline)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Tanpa sinyal — tombol mati. WiFi nyala tapi lemot tetap bisa dicoba; bila gagal, banner merah yang bicara. Data lokal tetap aman.',
                                style: AppType.secondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  SettingRow(
                    icon: Icons.group_outlined,
                    title: 'Gabung rumah tangga',
                    subtitle: 'Pakai kode 8 huruf dari pengundang',
                    onTap: _busy
                        ? null
                        : () => setState(() {
                              _showJoin = !_showJoin;
                              _showCreate = false;
                            }),
                  ),
                  if (_showJoin)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 9,
                            decoration: InputDecoration(
                              labelText: 'Kode invite',
                              hintText: 'cth. ABCD-EFGH',
                              errorText: _codeCtrl.text.isEmpty
                                  ? null
                                  : (InviteCode.isValid(_codeCtrl.text)
                                      ? null
                                      : friendlyJoinError(JoinFailure.badCode)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: (_busy ||
                                    offline ||
                                    !InviteCode.isValid(_codeCtrl.text))
                                ? null
                                : () => _run(() =>
                                    svc.joinHousehold(_codeCtrl.text)),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(offline
                                    ? 'Gabung (tanpa sinyal)'
                                    : 'Gabung'),
                          ),
                          if (offline)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Tanpa sinyal — tombol mati. WiFi nyala tapi lemot tetap bisa dicoba; bila gagal, banner merah yang bicara. Data lokal tetap aman.',
                                style: AppType.secondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        );
      case FamilyStatus.household:
        return Column(
          children: [
            if (_errorMsg != null) _errorCard(),
            if (_match('anggota', 'rumah', const ['household', 'nama']))
              SettingsGroup(
                title: 'Rumah tangga',
                children: [
                  SettingRow(
                    icon: Icons.home_outlined,
                    title: s.householdName ?? 'Keluarga',
                    subtitle:
                        'Masuk sebagai ${s.displayName ?? s.email ?? 'anggota'}',
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmLeaveHousehold(svc, s),
                      child: const Text('Keluar'),
                    ),
                  ),
                  // Daftar anggota: TAP = kelola (bottom sheet peran/keluar).
                  // Offline/gagal = fallback teks, bukan error.
                  FutureBuilder<List<HouseholdMember>>(
                    future: svc.fetchMembers(),
                    builder: (c, snap) {
                      final members = snap.data ?? const <HouseholdMember>[];
                      if (members.isEmpty) {
                        return SettingRow(
                          icon: Icons.people_outlined,
                          title: 'Anggota',
                          subtitle: offline
                              ? 'Offline — daftar tampil saat online.'
                              : 'Memuat…',
                        );
                      }
                      return SettingRow(
                        icon: Icons.people_outlined,
                        title:
                            'Anggota (${members.length})',
                        subtitle: members
                            .map((m) =>
                                '${m.shownName} · ${m.roleLabel}')
                            .join('\n'),
                        onTap: (_busy || offline)
                            ? null
                            : () => _manageMembers(svc, s, members),
                      );
                    },
                  ),
                  SettingRow(
                    icon: Icons.key_outlined,
                    title: 'Kode invite',
                    subtitle: 'Berlaku 24 jam — bagikan ke pasangan',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20),
                          tooltip: 'Bagikan kode (WA, dll)',
                          onPressed: (_busy || offline)
                              ? null
                              : () => _shareInvite(svc, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Salin kode',
                          onPressed: (_busy || offline)
                              ? null
                              : () async {
                                  final code =
                                      await svc.activeInviteCode();
                                  if (!mounted) return;
                                  if (code == null) {
                                    setState(() {
                                      _errorMsg =
                                          'Kode kedaluwarsa — putar kode baru di bawah.';
                                      _retryJob = null;
                                    });
                                    return;
                                  }
                                  await Clipboard.setData(
                                      ClipboardData(text: code));
                                  _snack('Kode $code disalin.');
                                },
                        ),
                      ],
                    ),
                  ),
                  // Putar kode: hanya owner. Non-owner = baris info, bukan
                  // tombol gagal di server.
                  FutureBuilder<bool>(
                    future: svc.isOwner(),
                    builder: (c, snap) {
                      final owner = snap.data ?? false;
                      if (!owner) {
                        return const SettingRow(
                          icon: Icons.refresh_outlined,
                          title: 'Putar kode baru',
                          subtitle: 'Hanya pengelola yang bisa putar kode',
                        );
                      }
                      return SettingRow(
                        icon: Icons.refresh_outlined,
                        title: 'Putar kode baru',
                        subtitle: 'Kode lama langsung hangus',
                        trailing: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : null,
                        onTap: (_busy || offline)
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _errorMsg = null;
                                  _retryJob = null;
                                });
                                try {
                                  final code =
                                      await svc.rotateInviteCode();
                                  if (!mounted) return;
                                  await Clipboard.setData(
                                      ClipboardData(text: code));
                                  _snack('Kode baru $code disalin.');
                                } on FamilyException catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMsg = e.message;
                                    });
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _busy = false);
                                  }
                                }
                              },
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sectionGap),
            if (_match('sinkron', 'status', const ['sync', 'cloud']))
              SettingsGroup(
                title: 'Sinkronisasi',
                children: [
                  _syncRow(svc),
                  SettingRow(
                    icon: Icons.logout,
                    title: 'Keluar akun',
                    subtitle: s.email ?? '',
                    destructive: true,
                    onTap: _busy ? null : () => _run(svc.signOut),
                  ),
                ],
              ),
          ],
        );
    }
  }

  /// Baris sync beta (v1.19): status terakhir + tombol Sync sekarang.
  /// Tanpa household tombol tetap ada tapi service menolak ramah
  /// (kasus ini tidak terjadi: section ini hanya di status household).
  ///
  /// Kelola anggota (v1.19.1): bottom sheet daftar + aksi per anggota.
  /// - Owner → anggota lain: Naikkan/Turunkan peran, Keluarkan.
  /// - Siapa pun → diri sendiri: Keluar rumah (= leaveHousehold).
  /// Semua aksi pakai guard [AuthService.canRemoveMember] + konfirmasi
  /// dialog. Sukses = refresh daftar (setState) + snackbar.
  Future<void> _manageMembers(
    AuthService svc,
    FamilySession s,
    List<HouseholdMember> members,
  ) async {
    final owner = await svc.isOwner();
    if (!mounted) return;
    final ownerCount = members.where((m) => m.isOwner).length;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        final scheme = Theme.of(c).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 8, AppSpacing.page, 24),
            children: [
              Text('Kelola anggota',
                  style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                owner
                    ? 'Kamu pengelola — atur peran / keluarkan anggota.'
                    : 'Ketuk namamu untuk keluar rumah.',
                style: Theme.of(c).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              for (final m in members) ...[
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      m.shownName.isEmpty
                          ? '?'
                          : m.shownName.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(m.shownName),
                  subtitle:
                      Text('${m.roleLabel}${m.uid == s.uid ? ' · kamu' : ''}'),
                  trailing: (m.uid == s.uid || owner)
                      ? const Icon(Icons.more_vert, size: 20)
                      : null,
                  onTap: (m.uid == s.uid || owner)
                      ? () {
                          Navigator.pop(c);
                          _memberActions(svc, s, m,
                              iAmOwner: owner, ownerCount: ownerCount);
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Aksi per anggota: ubah peran / keluarkan / keluar — dengan guard +
  /// dialog konfirmasi. [m] = target, [s] = sesi (untuk uid sendiri).
  Future<void> _memberActions(
    AuthService svc,
    FamilySession s,
    HouseholdMember m, {
    required bool iAmOwner,
    required int ownerCount,
  }) async {
    final isMe = m.uid == s.uid;
    final guard = AuthService.canRemoveMember(
      iAmOwner: iAmOwner,
      targetIsMe: isMe,
      targetIsOwner: m.isOwner,
      ownerCount: ownerCount,
    );
    // Pilihan tersedia tergantung peran + guard hapus.
    final actions = <({String label, bool danger, Future<void> Function() run})>[];
    if (iAmOwner && !isMe) {
      actions.add((
        label: m.isOwner ? 'Turunkan ke Anggota' : 'Naikkan ke Pengelola',
        danger: false,
        run: () => svc.setMemberRole(m.uid, !m.isOwner),
      ));
    }
    if (guard == null) {
      actions.add((
        label: isMe ? 'Keluar rumah' : 'Keluarkan ${m.shownName}',
        danger: true,
        run: () => isMe
            ? svc.leaveHousehold().then((_) {})
            : svc.removeMember(m.uid),
      ));
    }
    if (actions.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMsg = guard ?? 'Tidak ada aksi untuk anggota ini.';
        _rawError = guard;
        _retryJob = null;
      });
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(m.shownName),
              subtitle: Text(m.roleLabel),
            ),
            const Divider(height: 1),
            for (var i = 0; i < actions.length; i++)
              ListTile(
                leading: Icon(
                  actions[i].danger
                      ? Icons.person_remove_outlined
                      : Icons.swap_horiz_outlined,
                  color: actions[i].danger
                      ? Theme.of(c).colorScheme.error
                      : null,
                ),
                title: Text(
                  actions[i].label,
                  style: actions[i].danger
                      ? TextStyle(color: Theme.of(c).colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.pop(c, i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final act = actions[picked];
    // Keluar sendiri sebagai pengelola-terakhir = peringatan ekstra
    // (sama kayak tombol Keluar utama) — bukan blokir.
    final lastOwnerWarn = isMe && iAmOwner && ownerCount <= 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(act.label),
        content: Text(act.danger
            ? (isMe
                ? 'Keluar dari ${s.householdName ?? 'rumah'}? Data lokal HP ini tetap aman, sync berhenti.'
                    '${lastOwnerWarn ? '\n\nPERHATIAN: kamu pengelola satu-satunya — rumah jadi kosong tanpa pengelola.' : ''}'
                : '${m.shownName} tidak bisa mencatat lagi sampai gabung ulang. Lanjutkan?')
            : '${m.shownName} akan menjadi ${m.isOwner ? 'Anggota' : 'Pengelola'}. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: act.danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                    foregroundColor: Theme.of(c).colorScheme.onError,
                  )
                : null,
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
      _rawError = null;
      _retryJob = null;
    });
    try {
      await act.run();
      if (!mounted) return;
      setState(() {}); // refresh FutureBuilder anggota
      _snack('${act.label} — berhasil.');
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Gagal — coba lagi.';
        _rawError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _syncRow(AuthService svc) {
    final st = ref.watch(syncStateProvider);
    final busy = st.phase == SyncPhase.working;
    final subtitle = switch (st.phase) {
      SyncPhase.idle =>
        'Beta — kirim & ambil transaksi + kategori serumah',
      SyncPhase.working => st.message.isEmpty ? 'Sinkron…' : st.message,
      SyncPhase.done =>
        'Terakhir OK: +${st.pushed} kirim, +${st.pulled} terima',
      SyncPhase.failed => st.message.isEmpty ? 'Gagal.' : st.message,
    };
    return SettingRow(
      icon: Icons.cloud_outlined,
      title: 'Sync data',
      subtitle: subtitle,
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: busy
          ? null
          : () async {
              final db = ref.read(dbProvider);
              final sync = ref.read(syncServiceProvider);
              ref.read(syncStateProvider.notifier).state = const SyncState(
                phase: SyncPhase.working,
                message: 'Menyiapkan…',
              );
              final res = await sync.syncNow(
                db,
                onProgress: (tahap) {
                  ref.read(syncStateProvider.notifier).state = SyncState(
                    phase: SyncPhase.working,
                    message: tahap,
                  );
                },
              );
              ref.read(syncStateProvider.notifier).state = res;
              if (!mounted) return;
              if (res.phase == SyncPhase.done) {
                _snack(
                    'Sync OK: ${res.pushed} kirim, ${res.pulled} terima.');
              } else {
                setState(() {
                  _errorMsg = res.message;
                  _rawError = res.message;
                  _retryJob = null;
                });
              }
            },
    );
  }

  /// Hero empty-state status personal: ikon + ajakan + 3 manfaat +
  /// tombol Google besar. Mengisi ruang kosong yang sebelumnya kopong.
  Widget _personalHero(AuthService svc) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.group_outlined,
                    size: 32,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  'Catat bareng pasangan',
                  style: AppType.sectionTitle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Satu rumah tangga, dua HP. Opsional — '
                  'tanpa login aplikasi tetap 100% offline.',
                  style: AppType.secondary(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s12),
                _benefit(Icons.sync_outlined,
                    'Saling nyatat, saldo ikut (beta — tap Sync data)'),
                _benefit(Icons.lock_outlined,
                    'Data lokal HP ini tidak tersentuh'),
                _benefit(Icons.key_outlined,
                    'Gabung cukup pakai kode 8 huruf'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(svc.signIn),
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.login),
          label: Text(_busy ? 'Menghubungkan…' : 'Masuk dengan Google'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Butuh internet sekali saat login. Gagal? Pesan merah '
          'di atas menjelaskan sebabnya + tombol Coba lagi.',
          style: AppType.secondary(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedOf(context)),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(text, style: AppType.secondaryStrong(context)),
          ),
        ],
      ),
    );
  }
}
