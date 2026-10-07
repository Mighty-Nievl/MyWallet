import 'package:flutter/material.dart';

/// Progress bar konsisten di seluruh aplikasi
/// (Beranda kategori, Budget, Laporan).
///
/// Track = abu-abu terang ([surfaceContainerHighest]) agar batas 100%
/// selalu kelihatan; fill = warna semantik dari pemanggil
/// (normal = primary, warning = tertiary, lewat batas = error).
/// Threshold tetap milik logika pemanggil.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest,
        color: color,
      ),
    );
  }
}
