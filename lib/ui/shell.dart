import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/app_radius.dart';
import 'design/app_shadows.dart';
import 'scan_flow.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tx_form_screen.dart';

/// Kerangka utama v1.29.1: [Riwayat] [ (＋) ] [Scan].
///
/// Beranda pensiun dari navbar (redundant: shell satu halaman, tap-nya
/// no-op) → slot kiri jadi pintasan Riwayat (push, ikut pola grid
/// Beranda). Tombol tengah = lingkaran solid primer 72px overlap di
/// atas bar, buka form Catat (pintu tunggal).
/// Scan = tab kanan, tap = alur [runScanFlow] (bukan halaman).
///
/// Pengaturan tetap di gear header Beranda (bukan tab).
///
/// Identitas v1.28: bar navigasi MELAYANG (margin + kartu 24 + shadow
/// lembut menyebar), tombol tengah glow aksen via token.
///
/// Fix v1.29.1: lingkaran tengah JANGAN digeser pakai transform — ia
/// melukis di luar batas ClipRRect bar (12px kepala di luar clip,
/// rawan kepotong di GPU HP). Overlap dibangun via Stack
/// (clipBehavior: none) + SafeArea (gesture-nav HP tak menempel pil
/// sistem). Tampilan dipertahankan: lingkaran tetap menonjol ke atas.
///
/// v1.32 (request user "navbar terlalu lebar" + "tombol + kurang gede"):
/// bar 72→60 (ramping), tombol 64→72 + ikon 28→32 (magnet lebih kuat).
/// Overlap -16 tetap (kepala proporsional: 72/2+16 = 52 vs bar 60).
///
/// v1.32.1 (request susulan "bar masih lebar"): bar 60→48 = batas
/// sentuh minimum (touchMin 48, kolom ikon+label center muat 36px).
/// Kepala tombol di atas bar tetap 16 (overlap -16 tak berubah); ekor
/// 8px lingkaran jatuh ke margin bawah 12 (Stack clip none, aman).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  void _catat(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TxFormScreen()));
  }

  void _riwayat(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final labels = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      body: const HomeScreen(),
      // Tombol Catat menonjol: lingkaran solid overlap di atas bar.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('home:navbar'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppShadows.floating(context),
          ),
          child: SizedBox(
            // v1.32.1: 60→48 (request susulan "bar masih lebar"; batas
            // bawah = touchMin 48 agar target sentuh tetap lolos).
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Riwayat: pintasan layar paling sering dibuka
                    // (pengganti Beranda yang no-op).
                    Expanded(
                      child: InkWell(
                        onTap: () => _riwayat(context),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            Text(
                              'Riwayat',
                              style: labels?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Ruang tengah untuk lingkaran overlap.
                    const Expanded(child: SizedBox()),
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
                              style: labels?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Tombol tengah: magnet mata, satu-satunya pintu catat.
                // Posisi via Stack (bukan transform) → tak ada piksel
                // di luar clip; 16px kepala di atas bar = overlap resmi.
                Positioned(
                  left: 0,
                  right: 0,
                  top: -16,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _catat(context),
                      child: Semantics(
                        button: true,
                        label: 'Catat transaksi',
                        child: Container(
                          // v1.32: 64→72 + ikon 28→32 (request user
                          // "tombol + kurang gede"); bar ikut ramping 60.
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.glow(context),
                          ),
                          child: Icon(
                            Icons.add,
                            color: scheme.onPrimary,
                            size: 32,
                          ),
                        ),
                      ),
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
