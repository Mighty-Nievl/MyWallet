import 'package:flutter/material.dart';

import '../design/app_typography.dart';
import 'app_feedback.dart';

/// Header layar: judul besar + tombol aksi kotak.
///
/// Bahasa yang sama di Beranda (pinned), Riwayat, Budget, Laporan.
/// Tombol aksi via [AppIconButton] — radius ikut token, sentuh 48px.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String title;

  /// Sapaan/tanggal kecil di atas judul (dipakai Beranda pinned).
  final String? subtitle;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
          ),
      ],
    );
  }
}
