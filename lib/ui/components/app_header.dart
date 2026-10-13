import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_feedback.dart';

/// Header layar: judul besar + tombol aksi polos.
///
/// Bahasa yang sama di Beranda (pinned), Riwayat, Budget, Laporan.
/// Tombol aksi via [AppIconButton] — radius ikut token, sentuh 48px.
/// v1.30.1: kembali juga polos (permintaan user 2026-10-13).
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.onBack,
  });

  final String title;

  /// Sapaan/tanggal kecil di atas judul (dipakai Beranda pinned).
  final String? subtitle;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  /// Tombol kembali di kiri judul (v1.26: layar Riwayat/Budget/Laporan/
  /// Utang dibuka via push dari grid Beranda, bukan tab — butuh jalan
  /// pulang. null = tanpa tombol, Beranda tak berubah).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          AppIconButton(
            icon: Icons.arrow_back,
            onPressed: onBack,
            tooltip: 'Kembali',
            // v1.30.1: tombol kembali polos (tanpa border) — permintaan
            // user 2026-10-13, samakan dgn tombol header lain.
            bordered: false,
          ),
        if (onBack != null) const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null) ...[
                Text(
                  subtitle!,
                  style: AppType.secondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Text(
                title,
                style: AppType.screenTitle(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (actionIcon != null && onAction != null)
          AppIconButton(
            icon: actionIcon!,
            onPressed: onAction,
            tooltip: actionTooltip,
            // v1.24.8: tombol header polos (kotak hilang, hit-area tetap).
            bordered: false,
          ),
      ],
    );
  }
}
