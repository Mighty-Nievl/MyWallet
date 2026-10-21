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
/// Beranda). Tombol tengah = lingkaran solid primer yang duduk flush di
/// dalam kapsul, buka form Catat (pintu tunggal).
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
/// sistem).
///
/// v1.32.1 (request user: "lebar" = bentang HORIZONTAL): dock kompak
/// 232px, tinggi 56, lingkaran 56 FLUSH dalam kapsul (v1.32.4).
///
/// v1.33.0 (request user "dock-nya jadi FAB, tapi bentuknya tetap
/// dock"): kapsul yang SAMA dipindah dari `bottomNavigationBar` ke slot
/// `floatingActionButton` + `centerFloat`. Bedanya nyata: slot bottom
/// NavigationBar memotong body setinggi dirinya (viewport 844→776),
/// sedangkan slot FAB melayang DI ATAS body — kapsul benar-benar
/// mengambang dan konten boleh lewat di belakangnya.
///
/// Konsekuensi yang disengaja: viewport body kini penuh. Clearance ekor
/// Beranda (`AppSpacing.bottomPad` = dockSlot 68 + breath 44 +
/// safeBottom) tetap menjaga konten terakhir berhenti bersih di atas
/// kapsul saat scroll mentok.
///
/// Jarak bawah: kFloatingActionButtonMargin (16) dari Scaffold
/// menggantikan `margin: bottom 12` milik bar lama; SafeArea(top:
/// false) di DALAM slot menjaga kapsul tetap di atas pil gestur HP.
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
      // v1.33.0: kapsul = FAB. Jangan dibungkus Center/Align — slot FAB
      // sudah menghitung ukuran child-nya sendiri, dan Center di slot
      // lama pernah bikin body 0px (regresi v1.32.2).
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('home:navbar'),
          width: 232,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: scheme.outlineVariant),
            // v1.32.5: dock() ramping (blur 20/offset 4), bukan
            // floating() (blur 32/offset 12) — proporsional kapsul 56.
            boxShadow: AppShadows.dock(context),
          ),
          child: SizedBox(
            height: 56,
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
                    // Ruang tengah untuk lingkaran.
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
                // v1.32.4: lingkaran 56 + ikon 28, FLUSH (top 0) duduk di
                // DALAM kapsul — tak ada piksel di atas kapsul. 48 gagal
                // (Center menengahkan ulang, rect Semantics tetap 56);
                // top 8 gagal (makan body bawah). 56 = magnet + aman.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _catat(context),
                      child: Semantics(
                        button: true,
                        label: 'Catat transaksi',
                        child: Container(
                          width: 56,
                          height: 56,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
