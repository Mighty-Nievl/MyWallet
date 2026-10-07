import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Pembungkus section Beranda: judul semibold + spasi konsisten.
///
/// [trailing] opsional, mis. tombol "Lihat semua".
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppType.sectionTitle(context))),
            if (trailing case final Widget t) t,
          ],
        ),
        const SizedBox(height: AppSpacing.groupGap),
        child,
      ],
    );
  }
}
