import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/app_radius.dart';
import 'design/app_shadows.dart';
import 'scan_flow.dart';
import 'screens/home_screen.dart';
import 'screens/tx_form_screen.dart';

/// Kerangka utama v1.26: [Beranda] [ (＋) ] [Scan].
///
/// Riwayat/Budget/Laporan/Utang pindah ke grid Beranda (push, bukan tab).
/// Tombol tengah = lingkaran solid primer ±64px overlap di atas bar,
/// buka form Catat (pintu tunggal — FAB lama dihapus di commit yang sama).
/// Scan = tab kanan, tap = alur [runScanFlow] (bukan halaman).
///
/// Pengaturan tetap di gear header Beranda (bukan tab).
///
/// Identitas v1.28: bar navigasi MELAYANG (margin + kartu 24 + shadow
/// lembut menyebar), tombol tengah glow aksen via token.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  void _catat(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TxFormScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: const HomeScreen(),
      // Tombol Catat menonjol: lingkaran solid overlap di atas bar.
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: AppShadows.floating(context),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardAll,
          child: BottomAppBar(
            height: 72,
            padding: EdgeInsets.zero,
            color: Colors.transparent,
            elevation: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Beranda: aktif selalu (satu-satunya halaman shell).
                Expanded(
                  child: InkWell(
                    onTap: () => HapticFeedback.selectionClick(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home, color: scheme.primary),
                        Text(
                          'Beranda',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tombol tengah: magnet mata, satu-satunya pintu catat.
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _catat(context),
                      child: Semantics(
                        button: true,
                        label: 'Catat transaksi',
                        child: Container(
                          width: 64,
                          height: 64,
                          transform: Matrix4.translationValues(0, -16, 0),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.glow(context),
                          ),
                          child: Icon(
                            Icons.add,
                            color: scheme.onPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Scan: alur kamera/galeri → pratinjau → simpan.
                Expanded(
                  child: InkWell(
                    onTap: () => runScanFlow(context, ref),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        Text(
                          'Scan',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
