import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'category_icon.dart';

/// Empty state minimal yang dipakai ulang:
/// ikon netral + judul + deskripsi + aksi opsional.
///
/// Tanpa ilustrasi besar — sesuai bahasa STEP 1-2.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryIcon(icon: icon, size: 56, fontSize: 28),
            const SizedBox(height: AppSpacing.s16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppType.secondary(context),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
