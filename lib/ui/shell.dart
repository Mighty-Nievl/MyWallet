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
/// v1.29.1: lingkaran tengah JANGAN digeser pakai transform — ia melukis
/// di luar batas ClipRRect bar (12px kepala di luar clip, rawan kepotong
/// di GPU HP). Overlap dibangun via Stack (clipBehavior: none).
///
/// v1.32.1: kapsul kompak 232px (bentang horizontal, bukan tinggi),
/// tinggi 56, lingkaran 56 FLUSH dalam kapsul (v1.32.4).
///
/// v1.33.0 (request user "dock-nya jadi FAB, tapi bentuknya tetap
/// dock"): kapsul yang SAMA dipindah dari `bottomNavigationBar` ke slot
/// `floatingActionButton` + `centerFloat`. Bedanya nyata: slot bottom
/// NavigationBar memotong body setinggi dirinya (viewport 844→776),
/// sedangkan slot FAB melayang DI ATAS body — kapsul benar-benar
/// mengambang dan konten boleh lewat di belakangnya.
///
/// v1.33.1 (audit UI/UX setelah kapsul jadi overlay). Tiga cacat yang
/// lahir dari overlay itu diperbaiki di sini:
/// 1. P1 — teks yang lewat di belakang kapsul hilang mendadak di tepi,
///    dan border 1px terbaca seperti mengiris baris. Badan Beranda kini
///    punya scrim gradient 96px (transparan → surface) supaya teks
///    memudar halus sebelum menyentuh kapsul. Scrim `IgnorePointer` agar
///    tidak menelan tap.
/// 2. P2 — `InkWell` di dalam `Container` ber-`decoration` opaque: splash
///    digambar di Material terdekat (milik Scaffold) yang TERTUTUP warna
///    Container, jadi tap Riwayat/Scan tanpa feedback visual. Fix: isi
///    kapsul sekarang `Material(color: surface, shape: ..., clip)` →
///    ripple punya host sendiri di atas permukaan kapsul.
/// 3. P5 — label 11px di slot ±77px bisa wrap lalu overflow saat
///    textScaler HP diperbesar → label `maxLines: 1` + ellipsis, dan
///    skala teks chrome di-clamp 1.3 (chrome 56px, bukan konten).
///
/// Plus P7: kapsul menyelinap turun saat konten digulir ke bawah dan
/// kembali saat scroll berhenti — overlay permanen 56px menutupi item
/// yang sedang dibaca di daftar panjang.
///
/// Yang SENGAJA tidak diubah di v1.33.1: radius 16 (`AppRadius.card`,
/// bukan `pill`) dan susunan Riwayat · + · Scan — keduanya bentuk yang
/// diminta dipertahankan sejak v1.33.0.
///
/// Jarak bawah: kFloatingActionButtonMargin (16) dari Scaffold
/// menggantikan `margin: bottom 12` milik bar lama; SafeArea(top:
/// false) di DALAM slot menjaga kapsul tetap di atas pil gestur HP.
/// Clearance ekor Beranda (`AppSpacing.bottomPad` = dockSlot 68 +
/// breath 44 + safeBottom) tetap menjaga konten terakhir berhenti
/// bersih di atas kapsul saat scroll mentok.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// v1.33.1 (P7): kapsul tuck saat scroll turun, kembali saat berhenti.
  bool _tucked = false;
  double _lastPixels = 0;

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final dy = n.metrics.pixels - _lastPixels;
      _lastPixels = n.metrics.pixels;
      // Ambang 4px = abaikan jitter; jangan tuck saat masih di puncak.
      if (dy > 4 && n.metrics.pixels > 0) _setTucked(true);
    } else if (n is ScrollEndNotification) {
      _setTucked(false);
    }
    return false;
  }

  void _setTucked(bool value) {
    if (!mounted || _tucked == value) return;
    setState(() => _tucked = value);
  }

  void _catat() {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TxFormScreen()));
  }

  void _riwayat() {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      // P1: scrim gradient di badan Beranda. Slot FAB digambar Scaffold
      // DI ATAS body, jadi konten yang lewat di belakang kapsul memudar
      // halus alih-alih terpotong tepi kapsul + border.
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: const HomeScreen(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                key: const ValueKey('home:scrim'),
                height: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.surface.withValues(alpha: 0),
                        scheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // v1.33.0: kapsul = FAB. Jangan dibungkus Center/Align — slot FAB
      // sudah menghitung ukuran child-nya sendiri, dan Center di slot
      // lama pernah bikin body 0px (regresi v1.32.2).
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: IgnorePointer(
        ignoring: _tucked,
        child: AnimatedSlide(
          key: const ValueKey('home:fab-slide'),
          offset: _tucked ? const Offset(0, 1.4) : Offset.zero,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _tucked ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: SafeArea(
              top: false,
              child: Container(
                key: const ValueKey('home:navbar'),
                width: 232,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardAll,
                  // v1.32.5: dock() ramping (blur 20/offset 4) —
                  // proporsional kapsul 56.
                  boxShadow: AppShadows.dock(context),
                ),
                // P2: Material ini host ripple InkWell di dalamnya. Dulu
                // warna surface ada di Container DI ATAS Material milik
                // Scaffold → splash tak pernah kelihatan.
                child: Material(
                  color: scheme.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.cardAll,
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: SizedBox(
                    height: 56,
                    // P5: chrome 56px — clamp skala teks supaya label
                    // tidak wrap lalu overflow di HP berfont besar.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Riwayat: pintasan layar paling sering
                              // dibuka (pengganti Beranda yang no-op).
                              Expanded(
                                child: InkWell(
                                  customBorder: const RoundedRectangleBorder(
                                    borderRadius: AppRadius.cardAll,
                                  ),
                                  onTap: _riwayat,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        Text(
                                          'Riwayat',
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: labels?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Ruang tengah untuk lingkaran.
                              const Expanded(child: SizedBox()),
                              // Scan: alur kamera/galeri → pratinjau.
                              Expanded(
                                child: InkWell(
                                  customBorder: const RoundedRectangleBorder(
                                    borderRadius: AppRadius.cardAll,
                                  ),
                                  onTap: () => runScanFlow(context, ref),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.document_scanner_outlined,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        Text(
                                          'Scan',
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: labels?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Tombol tengah: magnet mata, satu-satunya pintu
                          // catat. 56 + ikon 28, FLUSH (top 0) di DALAM
                          // kapsul — tak ada piksel di atas kapsul.
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _catat,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
