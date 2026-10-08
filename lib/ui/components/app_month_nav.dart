import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../format.dart';
import 'app_feedback.dart';

/// Navigasi bulan terpusat — bahasa yang sama di
/// Beranda, Riwayat, Budget, dan Laporan.
///
/// Logika geser bulan milik pemanggil (tidak diubah).
/// Desain: chevron 48px + chip bulan (ketuk = bulan ini lagi bila
/// sedang lihat bulan lain) + tombol "Bulan ini" saat bukan bulan berjalan.
class AppMonthNav extends StatelessWidget {
  const AppMonthNav({super.key, required this.month, required this.onShift});

  /// Kunci bulan "yyyy-MM".
  final String month;
  final void Function(int delta) onShift;

  @override
  Widget build(BuildContext context) {
    final isCurrent = month == currentMonthKey();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Bulan sebelumnya',
              onPressed: () => onShift(-1),
            ),
            const SizedBox(width: AppSpacing.s8),
            // Chip bulan: label + hint bisa digeser. Ketuk saat lihat
            // bulan lain = kembali ke bulan ini.
            Tooltip(
              message: isCurrent
                  ? 'Geser chevron untuk ganti bulan'
                  : 'Ketuk untuk kembali ke bulan ini',
              child: ActionChip(
                label: Text(
                  monthLabel(month),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                avatar: Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: isCurrent
                    ? null
                    : () => onShift(_deltaToCurrent(month)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            AppIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Bulan berikutnya',
              onPressed: () => onShift(1),
            ),
          ],
        ),
        if (!isCurrent) ...[
          const SizedBox(height: AppSpacing.s4),
          TextButton.icon(
            onPressed: () => onShift(_deltaToCurrent(month)),
            icon: const Icon(Icons.today_outlined, size: 16),
            label: const Text('Kembali ke bulan ini'),
            style: TextButton.styleFrom(
              minimumSize: const Size(AppSpacing.touchMin, 36),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  /// Selisih bulan dari [month] ke bulan berjalan (untuk lompat balik).
  static int _deltaToCurrent(String month) {
    try {
      final parts = month.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final now = DateTime.now();
      return (now.year - y) * 12 + (now.month - m);
    } catch (_) {
      return 0;
    }
  }
}

/// Jarak standar setelah AppMonthNav (dipakai semua layar).
const monthNavBottomGap = SizedBox(height: AppSpacing.s16);
