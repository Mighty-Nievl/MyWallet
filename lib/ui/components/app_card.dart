import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';

/// Kartu B2C (v1.20): permukaan + border tipis + bayangan lembut.
/// Satu sentuh di sini = Budget/Reports/Utang/Kategori/Riwayat ikut
/// premium. Public API TETAP: [child] + [padding] + [margin].
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.borderOf(context)),
        // B2C v1.20: bayangan SANGAT lembut — kartu terangkat dari
        // latar tanpa kesan flat. Alpha 5% = aman di dark/true-black.
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
