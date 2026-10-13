import 'package:flutter/material.dart';

import '../design/app_motion.dart';
import '../design/app_radius.dart';

/// Progress bar konsisten di seluruh aplikasi
/// (Beranda kategori, Budget, Laporan).
///
/// Track = abu-abu terang ([surfaceContainerHighest]) agar batas 100%
/// selalu kelihatan; fill = warna semantik dari pemanggil
/// (normal = primary, warning = tertiary, lewat batas = error).
/// Threshold tetap milik logika pemanggil.
///
/// B2C v1.20: fill ANIMASI halus (TweenAnimationBuilder) tiap nilai
/// berubah — bukan lompat. Hormati disableAnimations sistem.
class AppProgress extends StatelessWidget {
  const AppProgress({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  /// 0.0 – 1.0 (dijepit otomatis).
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = value.clamp(0.0, 1.0);
    if (AppMotion.animationsOff(context)) {
      return ClipRRect(
        borderRadius: AppRadius.pillAll,
        child: LinearProgressIndicator(
          value: target,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          color: color,
        ),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          color: color,
        ),
      ),
    );
  }
}
