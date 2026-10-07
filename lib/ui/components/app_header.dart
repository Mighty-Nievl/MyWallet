import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// Header layar: judul besar + tombol aksi berboder.
/// Bahasa yang sama dengan header Beranda & Riwayat.
///
/// [actionIcon]/[onAction] opsional — mis. kalender atau tambah.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String title;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppType.screenTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionIcon != null && onAction != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: IconButton(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 20),
              tooltip: actionTooltip,
              constraints:
                  const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
