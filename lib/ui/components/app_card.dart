import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';

/// Kartu subtle ala shadcn: permukaan + border tipis, tanpa shadow.
///
/// Hanya untuk STEP 1 yang butuh (saldo, ringkasan, empty-state).
/// Kartu generik lain tetap pakai Card bawaan tema.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: child,
    );
  }
}
