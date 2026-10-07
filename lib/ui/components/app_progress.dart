import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// Progress bar subtle yang konsisten di seluruh aplikasi
/// (Beranda kategori, Budget, Laporan).
///
/// Track = permukaan sekunder netral, fill = warna semantik
/// dari pemanggil (normal = primary, warning = tertiary,
/// lewat batas = error). Threshold tetap milik logika pemanggil.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.subtleOf(context),
        color: color,
      ),
    );
  }
}
