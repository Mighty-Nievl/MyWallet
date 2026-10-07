import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../format.dart';

/// Navigasi bulan terpusat — bahasa yang sama di
/// Beranda, Riwayat, Budget, dan Laporan.
///
/// Logika geser bulan milik pemanggil (tidak diubah).
class AppMonthNav extends StatelessWidget {
  const AppMonthNav({super.key, required this.month, required this.onShift});

  /// Kunci bulan "yyyy-MM".
  final String month;
  final void Function(int delta) onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          icon: const Icon(Icons.chevron_left),
          constraints:
              const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
        Text(monthLabel(month),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: () => onShift(1),
          icon: const Icon(Icons.chevron_right),
          constraints:
              const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Jarak standar setelah AppMonthNav (dipakai semua layar).
const monthNavBottomGap = SizedBox(height: AppSpacing.s16);
