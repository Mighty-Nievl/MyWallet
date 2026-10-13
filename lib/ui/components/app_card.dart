import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';

/// Kartu melayang (identitas v1.28, radius 16 sejak v1.30.1): permukaan +
/// border tipis + bayangan lembut menyebar + radius ramah.
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
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.borderOf(context)),
        // Identitas v1.28: bayangan lembut menyebar (hitam 8% blur 24)
        // — kartu terangkat melayang, bukan flat, bukan pekat.
        boxShadow: AppShadows.card(context),
      ),
      child: child,
    );
  }
}
