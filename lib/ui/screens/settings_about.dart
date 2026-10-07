import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'settings_actions.dart';

/// Sub-halaman Tentang: info versi (ketuk salin) + changelog.
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
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  final v = snap.data;
                  final info =
                      'MyWallet v${v?.version ?? '…'} (${v?.buildNumber ?? '…'})';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$info\n'
                              'Pencatat keuangan pribadi — offline-first.\n'
                              'Seluruh data tersimpan lokal di HP kamu.',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Salin info versi',
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: info));
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Info versi disalin — tempel saat lapor bug.')),
                                );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: showChangelog,
                        icon: const Icon(Icons.history),
                        label: const Text('Lihat changelog'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
