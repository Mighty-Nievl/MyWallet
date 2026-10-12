import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/household.dart';
import '../../data/settings.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../greeting.dart';
import 'family_screen.dart';
import 'settings_actions.dart';

/// Halaman Profil (v1.27): akun Google + nama panggilan lokal editable +
/// pintu Keluarga. Pohon akun: Beranda (avatar) → Profil → Keluarga.
///
/// Foto/nama Google read-only (label jujur "dari akun Google"); yang
/// editable = nama panggilan lokal (`displayNameProvider`, maxLength 20,
/// dipakai sapaan header via `greetingText`).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SettingsActions {
  bool _busy = false;
  String? _errorMsg;

  Future<void> _run(Future<FamilySession> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      await job();
    } on FamilyException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'Gagal — coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(familySessionProvider);
    final nickname = ref.watch(displayNameProvider);
    final svc = ref.read(authServiceProvider);

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
              child: BackHeader(title: 'Profil'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  AppSpacing.bottomPad,
                ),
                children: [
                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.s12,
                      ),
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  session.when(
                    loading: () => const AppSkeleton(lines: 3),
                    error: (_, _) => const Text(
                      'Gagal memuat sesi — mode pribadi (offline).',
                    ),
                    data: (s) => _body(s, nickname, svc),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    FamilySession s,
    AsyncValue<String> nickname,
    AuthService svc,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final loggedIn = !s.isPersonal;
    final googleName = (s.displayName ?? '').trim();
    final nick = nickname.value ?? '';
    final shown = resolveGreetingName(manualName: nick, googleName: googleName);
    final initial = (shown ?? 'M').characters.first.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kartu identitas: avatar inisial + nama + email.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    initial,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shown ?? 'Pengguna MyWallet',
                        style: AppType.sectionTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.micro),
                      Text(
                        loggedIn
                            ? (s.email ?? '')
                            : 'Belum masuk — mode pribadi',
                        style: AppType.secondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (loggedIn && googleName.isNotEmpty)
                        Text(
                          'Nama dari akun Google',
                          style: AppType.secondary(context),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGapLarge),
        SettingsGroup(
          title: 'Akun',
          children: [
            // Nama panggilan LOKAL — editable (bukan nama Google).
            SettingRow(
              icon: Icons.waving_hand_outlined,
              title: 'Nama panggilan',
              subtitle: 'Sapaan di Beranda, mis. “Selamat pagi, ReWin”',
              trailing: SettingValue(
                value: nickname.when(
                  loading: () => '…',
                  error: (_, _) => '…',
                  data: (n) => n.isEmpty ? 'Ikut akun' : n,
                ),
              ),
              onTap: _busy ? null : () => editDisplayName(),
            ),
            // Pintu Keluarga (pohon akun).
            SettingRow(
              icon: Icons.group_outlined,
              title: 'Keluarga',
              subtitle: switch (s.status) {
                FamilyStatus.household =>
                  s.householdName ?? 'Anggota rumah tangga',
                FamilyStatus.signedIn => s.email ?? 'Sudah masuk',
                _ => 'Catat bareng pasangan',
              },
              onTap: _busy
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FamilyScreen(),
                        ),
                      );
                    },
            ),
            // Masuk / keluar Google.
            SettingRow(
              icon: loggedIn ? Icons.logout : Icons.login,
              title: loggedIn ? 'Keluar akun' : 'Masuk dengan Google',
              subtitle: loggedIn
                  ? (s.email ?? '')
                  : 'Sync + rumah tangga (opsional)',
              destructive: loggedIn,
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _busy
                  ? null
                  : () => _run(loggedIn ? svc.signOut : svc.signIn),
            ),
          ],
        ),
      ],
    );
  }
}
