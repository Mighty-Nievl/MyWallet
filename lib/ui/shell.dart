import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/app_radius.dart';
import 'design/app_shadows.dart';
import 'design/app_spacing.dart';
import 'scan_flow.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tx_form_screen.dart';

/// Kerangka utama v1.29.1: [Riwayat] [ (＋) ] [Scan] — kapsul melayang.
///
/// Beranda pensiun dari navbar (redundant: shell satu halaman, tap-nya
/// no-op) → slot kiri jadi pintasan Riwayat (push, ikut pola grid
/// Beranda). Tombol tengah = lingkaran solid primer yang duduk flush di
/// dalam kapsul, buka form Catat (pintu tunggal).
/// Scan = tab kanan, tap = alur [runScanFlow] (bukan halaman).
/// Pengaturan tetap di gear header Beranda (bukan tab).
///
/// v1.29.1: lingkaran tengah JANGAN digeser pakai transform — ia melukis
/// di luar batas ClipRRect bar, rawan kepotong di GPU HP.
///
/// v1.32.1: kapsul kompak 232px (bentang horizontal, bukan tinggi),
/// tinggi 56, lingkaran 56 FLUSH dalam kapsul (v1.32.4).
///
/// v1.33.0: kapsul sempat dipindah ke slot `floatingActionButton` supaya
/// terlihat melayang, karena slot `bottomNavigationBar` memotong body
/// setinggi dirinya (viewport 844→776) — kapsul tak bisa menumpang
/// konten.
///
/// v1.33.1 (final): cara yang benar untuk "melayang" bukan slot FAB,
/// melainkan `extendBody: true`. Body dilukis sampai bawah layar dan
/// kapsul kembali ke slot `bottomNavigationBar`; hasil piksel SAMA
/// (konten lewat di belakang kapsul), tapi semantik & inset kembali
/// urusan Scaffold: bar dapat role navigasi, SnackBar otomatis naik di
/// atas kapsul, keyboard/safe-area tak ditambal manual, dan geometri
/// tak lagi dihitung dengan rumus FAB satu-tombol.
///
/// Perbaikan perilaku di versi yang sama (bentuk & susunan TIDAK diubah):
/// 1. P1 — teks yang lewat di belakang kapsul hilang mendadak di tepi.
///    Badan Beranda diberi scrim gradient (transparan → surface) yang
///    tingginya mengikuti token, bukan angka asal: `bottomPad` (120) +
///    safeBottom — sama dengan clearance ekor Beranda. Scrim
///    `IgnorePointer` dan ikut menyingkir saat kapsul tuck.
/// 2. P2 — `InkWell` di dalam `Container` opaque: splash digambar di
///    Material terdekat (milik Scaffold) yang TERTUTUP warna Container.
///    Fix: isi kapsul `Material(color: surface, shape, clip)`.
/// 3. P5 — label 11px di slot ±77px bisa wrap lalu overflow di font HP
///    besar → `maxLines: 1` + ellipsis + clamp skala 1.3.
/// 4. P7 — kapsul tuck saat scroll turun, kembali saat ScrollEnd atau
///    saat arah scroll berbalik (`_lastPixels` di-reset di ScrollStart).
/// 5. `+` diberi Material(primary) + InkWell lingkaran → akhirnya punya
///    ripple; sebelumnya satu-satunya kontrol tanpa pressed state.
/// 6. Zona mati dihapus: spacer tengah ikut men-tap Catat.
///
/// Jarak bawah kembali 12 (`margin`), bukan kFloatingActionButtonMargin
/// 16 — jadi rumus token pulih persis: bottomPad 120 = FAB 64 + margin
/// 12 + breath 44 (v1.36.0).
///
/// v1.36.0 (request user): `+` dibesarkan ke 64 dan menonjol 8px di atas
/// kapsul. Kapsul tetap 56; lingkaran pindah ke Stack LUAR karena Material
/// kapsul meng-clip anaknya. Slot jadi 76 (64 + margin 12), bottomPad 120.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// v1.33.1 (P7): kapsul tuck saat scroll turun, kembali saat berhenti
  /// atau saat arah scroll berbalik ke atas.
  bool _tucked = false;
  double _lastPixels = 0;

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      // Reset baseline: tanpa ini, lompatan programatik (jumpTo/animateTo)
      // menghasilkan delta besar dan memicu tuck palsu.
      _lastPixels = n.metrics.pixels;
    } else if (n is ScrollUpdateNotification) {
      final dy = n.metrics.pixels - _lastPixels;
      _lastPixels = n.metrics.pixels;
      // Ambang 4px = abaikan jitter sentuhan.
      if (dy > 4 && n.metrics.pixels > 0) {
        _setTucked(true);
      } else if (dy < -4) {
        _setTucked(false);
      }
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TxFormScreen()));
  }

  void _riwayat() {
    HapticFeedback.selectionClick();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = Theme.of(context).textTheme.labelSmall;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      // v1.33.1: body menumpang ke bawah kapsul — ini yang membuat
      // kapsul terlihat melayang, bukan slotnya.
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: const HomeScreen(),
          ),
          // P1: scrim gradient. Kapsul digambar Scaffold DI ATAS body,
          // jadi teks yang lewat di belakangnya memudar halus alih-alih
          // terpotong tepi kapsul + border 1px.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              // Ikut tuck: kalau kapsul menyingkir, kabut harus ikut
              // hilang — kalau tidak, layar berkabut tanpa alasan.
              child: AnimatedOpacity(
                opacity: _tucked ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: SizedBox(
                  key: const ValueKey('home:scrim'),
                  // Token yang sama dengan clearance ekor Beranda: ujung
                  // fade selalu berakhir di atas kapsul.
                  height: AppSpacing.bottomPad + safeBottom,
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
          ),
        ],
      ),
      // Kapsul di slot bar (bukan FAB): role navigasi benar, SnackBar
      // otomatis naik di atasnya, keyboard & safe-area urusan Scaffold.
      // Row-centered HANYA membungkus horizontal — Center/Align di slot
      // ini pernah mengembang penuhi slot vertikal (regresi v1.32.2).
      bottomNavigationBar: SafeArea(
        top: false,
        child: IgnorePointer(
          ignoring: _tucked,
          child: AnimatedSlide(
            key: const ValueKey('home:fab-slide'),
            offset: _tucked ? const Offset(0, 1.4) : Offset.zero,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _tucked ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'Navigasi utama',
                // v1.36.0: slot setinggi FAB 64 + margin 12. Lingkaran
                // duduk di Stack LUAR kapsul — Material kapsul meng-clip
                // anaknya, jadi overlap 8px mustahil kalau tetap di dalam.
                child: SizedBox(
                  height: AppSpacing.dockSlot,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: Container(
                            key: const ValueKey('home:navbar'),
                            width: 232,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.cardAll,
                              // v1.32.5: dock() ramping (blur 20/offset 4) —
                              // proporsional kapsul 56.
                              boxShadow: AppShadows.dock(context),
                            ),
                            // P2: Material ini host ripple InkWell di dalamnya.
                            // Dulu warna surface ada di Container DI ATAS
                            // Material milik Scaffold → splash tak kelihatan.
                            child: Material(
                              color: scheme.surface,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.cardAll,
                                side: BorderSide(color: scheme.outlineVariant),
                              ),
                              child: SizedBox(
                                height: 56,
                                // P5: chrome 56px — clamp skala teks supaya
                                // label tidak wrap lalu overflow di font besar.
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: 1.3,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Riwayat: pintasan layar paling
                                          // sering dibuka (pengganti Beranda
                                          // yang dulu no-op).
                                          Expanded(
                                            child: InkWell(
                                              customBorder:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        AppRadius.cardAll,
                                                  ),
                                              onTap: _riwayat,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .receipt_long_outlined,
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    Text(
                                                      'Riwayat',
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: labels?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Ruang tengah untuk lingkaran. v1.33.1:
                                          // area ini ikut men-tap Catat — dulu
                                          // ±10px di kiri-kanan lingkaran adalah
                                          // zona mati yang tidak melakukan apa pun.
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: _catat,
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                          // Scan: alur kamera/galeri → pratinjau.
                                          Expanded(
                                            child: InkWell(
                                              customBorder:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        AppRadius.cardAll,
                                                  ),
                                              onTap: () =>
                                                  runScanFlow(context, ref),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .document_scanner_outlined,
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    Text(
                                                      'Scan',
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: labels?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // v1.36.0: lingkaran 64 di LUAR Material kapsul.
                      // Bottom 12 = sejajar dasar kapsul; tinggi 64 → 8px
                      // menonjol ke atas (fabOverlap), 56px duduk di dalam.
                      Positioned(
                        bottom: 12,
                        child: Semantics(
                          button: true,
                          label: 'Catat transaksi',
                          child: Container(
                            width: AppSpacing.fabSize,
                            height: AppSpacing.fabSize,
                            // Glow di Container tanpa warna, supaya bayangan
                            // lingkaran tetap dari token.
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.glow(context),
                            ),
                            child: Material(
                              color: scheme.primary,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _catat,
                                child: Icon(
                                  Icons.add,
                                  color: scheme.onPrimary,
                                  size: 30,
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
    );
  }
}
