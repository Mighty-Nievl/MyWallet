import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../components/setting_row.dart';
import '../components/settings_scaffold.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'changelog_screen.dart';
import 'settings_actions.dart';

/// Sub-halaman Tentang: info versi (ketuk salin) + changelog.
///
/// v1.43.0: kerangka [SettingsScaffold]. Versi diambil sekali di
/// `initState` — dulu `FutureBuilder(PackageInfo.fromPlatform())` dibuat di
/// dalam `build`, jadi setiap rebuild memanggil platform channel lagi.
class AboutSettingsPage extends ConsumerStatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  ConsumerState<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends ConsumerState<AboutSettingsPage>
    with SettingsActions {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Tentang',
      children: [
        Center(
          child: ClipRRect(
            borderRadius: AppRadius.xxlAll,
            child: Image.asset(
              // v1.24.4: logo baru dari bg-white.jpg.
              'assets/images/bg-white.jpg',
              width: 88,
              height: 88,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.wallet_outlined, size: 48),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        SettingsGroup(
          title: 'Aplikasi',
          children: [
            FutureBuilder<PackageInfo>(
              future: _info,
              builder: (context, snap) {
                final v = snap.data;
                final info =
                    'MyWallet v${v?.version ?? '…'} (${v?.buildNumber ?? '…'})';
                return SettingRow(
                  icon: Icons.wallet_outlined,
                  title: info,
                  subtitle:
                      'Pencatat keuangan pribadi — offline-first. Seluruh data tersimpan lokal di HP kamu.',
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Salin info versi',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: info));
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Info versi disalin — tempel saat lapor bug.',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SettingRow(
              icon: Icons.history,
              title: 'Changelog',
              subtitle: 'Riwayat perubahan versi',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangelogScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          'Dibuat dengan Flutter · Data 100% lokal',
          textAlign: TextAlign.center,
          style: AppType.secondary(context),
        ),
      ],
    );
  }
}
