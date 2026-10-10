import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/household.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Sub-halaman Keluarga (Fase 1, v1.17): login Google + buat/gabung rumah
/// tangga + kode invite. Opt-in — tanpa login = offline murni.
///
/// STEP 4 — bahasa presentasi: [BackHeader] + [SettingsGroup] +
/// [SettingRow]; font-scale ikut via [AppType].
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

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? Theme.of(context).colorScheme.errorContainer : null,
      ),
    );
  }

  Future<void> _run(Future<FamilySession> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) {
        setState(() {
          _showCreate = false;
          _showJoin = false;
        });
      }
    } on FamilyException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Gagal — coba lagi.', error: true);
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

  Widget _body(FamilySession s, ColorScheme scheme) {
    final svc = ref.read(authServiceProvider);
    switch (s.status) {
      case FamilyStatus.loading:
        return const Padding(
            padding: EdgeInsets.all(16), child: AppSkeleton(lines: 3));
      case FamilyStatus.personal:
        return Column(
          children: [
            if (_match('login', 'google', const ['login', 'masuk']))
              SettingsGroup(
                title: 'Akun',
                children: [
                  SettingRow(
                    icon: Icons.login,
                    title: 'Masuk dengan Google',
                    subtitle:
                        'Opsional — tanpa login app tetap offline seperti sekarang',
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _busy ? null : () => _run(svc.signIn),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sectionGap),
            if (_match(
                'pasangan', 'bareng', const ['keluarga', 'sync', 'online']))
              Text(
                'Masuk dulu untuk catat bareng pasangan. '
                'Data lokal HP ini tidak tersentuh.',
                style: AppType.secondary(context),
              ),
          ],
        );
      case FamilyStatus.signedIn:
        return Column(
          children: [
            if (_match('akun', 'keluar', const ['email', 'profil']))
              SettingsGroup(
                title: 'Akun',
                children: [
                  SettingRow(
                    icon: Icons.account_circle_outlined,
                    title: s.displayName ?? s.email ?? 'Akun Google',
                    subtitle: (s.email ?? '') +
                        (s.displayName != null ? '' : ''),
                    trailing: TextButton(
                      onPressed:
                          _busy ? null : () => _run(svc.signOut),
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
                        children: [
                          TextField(
                            controller: _nameCtrl,
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
                            child: const Text('Buat'),
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
                            child: const Text('Gabung'),
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
            if (_match('anggota', 'rumah', const ['household', 'nama']))
              SettingsGroup(
                title: 'Rumah tangga',
                children: [
                  SettingRow(
                    icon: Icons.home_outlined,
                    title: s.householdName ?? 'Keluarga',
                    subtitle: s.email ?? '',
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
                          _snack('Kode kedaluwarsa — putar kode baru.',
                              error: true);
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
                            setState(() => _busy = true);
                            try {
                              final code =
                                  await svc.rotateInviteCode();
                              if (!mounted) return;
                              await Clipboard.setData(
                                  ClipboardData(text: code));
                              _snack('Kode baru $code disalin.');
                            } on FamilyException catch (e) {
                              _snack(e.message, error: true);
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
}
