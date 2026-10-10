import 'package:flutter/material.dart';

/// Token gerak B2C (v1.20): satu sumber durasi + kurva untuk seluruh app.
///
/// Aturan:
/// - Masuk/penekanan cepat (150-250ms), keluar sedikit lebih lambat.
/// - Daftar pakai stagger [staggerStep] (lihat [Stagger]).
/// - Hormati `MediaQuery.disableAnimations`: widget animasi wajib
///   render final langsung bila user mematikan animasi sistem.
abstract final class AppMotion {
  /// Tekan / ripple / hover.
  static const fast = Duration(milliseconds: 150);

  /// Transisi standar (sheet, dialog, angka, chip).
  static const normal = Duration(milliseconds: 250);

  /// Hero / kartu besar / transisi halaman.
  static const slow = Duration(milliseconds: 450);

  /// Jeda antar item daftar (stagger).
  static const staggerStep = Duration(milliseconds: 45);

  /// Kurva masuk (springy tapi tidak mantul berlebihan).
  static const easeOut = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Kurva keluar.
  static const easeIn = Cubic(0.64, 0.0, 0.78, 0.0);

  /// Kurva standar dua arah.
  static const standard = Curves.easeInOutCubic;

  static bool animationsOff(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Pembungkus entrance B2C: fade + geser naik ringan dengan delay
/// stagger per [index]. Bila animasi sistem mati → render [child]
/// langsung.
///
/// Implementasi TANPA timer/controller: [TweenAnimationBuilder] dengan
/// kurva [Interval] untuk jeda — tidak ada `Future.delayed`, tidak ada
/// `AnimationController`, jadi tidak pernah meninggalkan pending timer
/// di widget test (fake_async ngamuk kalau ada timer menggantung).
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.child,
    this.index = 0,
    this.distance = 14,
  });

  final Widget child;
  final int index;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.animationsOff(context)) return child;
    final delayMs = AppMotion.staggerStep.inMilliseconds * index.clamp(0, 8);
    final totalMs = AppMotion.normal.inMilliseconds + delayMs;
    final start = delayMs == 0 ? 0.0 : delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1.0, curve: AppMotion.easeOut),
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - v)),
          child: child,
        ),
      ),
    );
  }
}
