import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'settings_actions.dart';

/// Sub-halaman Tentang: info versi (ketuk salin) + changelog.
///
/// STEP 4 — hanya presentasi yang diubah. Sumber versi
/// ([PackageInfo]), tombol salin + SnackBar, dan changelog TETAP.
class AboutSettingsPage extends ConsumerStatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  ConsumerState<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends ConsumerState<AboutSettingsPage>
    with SettingsActions {
  @override
  Widget build(BuildContext context) {
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
              child: BackHeader(title: 'Tentang'),
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
                  SettingsGroup(
                    title: 'Aplikasi',
                    children: [
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
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
                                await Clipboard.setData(
                                    ClipboardData(text: info));
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Info versi disalin — tempel saat lapor bug.')),
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
                        onTap: showChangelog,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
