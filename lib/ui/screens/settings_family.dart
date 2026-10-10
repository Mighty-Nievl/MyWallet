import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/household.dart';
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
  String? _errorMsg;
  Future<FamilySession> Function()? _retryJob;

  @override
  void initState() {
    super.initState();
    _q = widget.initialQuery.trim().toLowerCase();
    if (_q.isNotEmpty) _searchCtrl.text = widget.initialQuery;
  }

  @override
  void dispose() {
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

  Future<void> _run(Future<FamilySession> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
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
          _retryJob = job;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Gagal — coba lagi.';
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
  Widget _errorCard() {
    final scheme = Theme.of(context).colorScheme;
    final retry = _retryJob;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              _errorMsg ?? 'Gagal.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (retry != null)
            TextButton(
              onPressed: _busy ? null : () => _run(retry),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
              ),
              child: const Text('Coba lagi'),
            ),
        ],
      ),
    );
  }

  Widget _body(FamilySession s, ColorScheme scheme) {
    final svc = ref.read(authServiceProvider);
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
                            decoration: const InputDecoration(
                              labelText: 'Nama rumah tangga',
                              hintText: 'cth. Keluarga Rezal',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy
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
                                : const Text('Buat'),
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
                            decoration: const InputDecoration(
                              labelText: 'Kode invite',
                              hintText: 'cth. ABCD-EFGH',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy
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
                                : const Text('Gabung'),
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
                      onPressed:
                          _busy ? null : () => _run(svc.leaveHousehold),
                      child: const Text('Keluar'),
                    ),
                  ),
                  SettingRow(
                    icon: Icons.key_outlined,
                    title: 'Kode invite',
                    subtitle: 'Berlaku 24 jam — bagikan ke pasangan',
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Salin kode',
                      onPressed: () async {
                        final code = await svc.activeInviteCode();
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
                  ),
                  SettingRow(
                    icon: Icons.refresh_outlined,
                    title: 'Putar kode baru',
                    subtitle: 'Kode lama langsung hangus',
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
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sectionGap),
            if (_match('sinkron', 'status', const ['sync', 'cloud']))
              SettingsGroup(
                title: 'Sinkronisasi',
                children: [
                  SettingRow(
                    icon: Icons.cloud_outlined,
                    title: 'Sync data',
                    subtitle:
                        'Segera hadir (Fase 2) — sekarang data tetap lokal per-HP',
                    onTap: () => _snack(
                        'Sync menyusul Fase 2 — sekarang tetap lokal.'),
                  ),
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
                    'Saling nyatat, saldo ikut (segera Fase 2)'),
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
