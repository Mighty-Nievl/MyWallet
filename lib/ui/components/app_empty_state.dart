import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import '../design/app_motion.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'category_glyph.dart';

/// Empty state B2C (v1.20) yang dipakai ulang:
/// medali gradien-aksen + ikon putih + judul + deskripsi + aksi.
///
/// Public API TETAP: [icon] + [title] + [subtitle] + [action] —
/// semua pemanggil lama jalan tanpa diubah. Yang berubah cuma
/// presentasi: emoji glyph kecil → medali besar bergradasi.
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
    final medal = AppGradients.medal(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Stagger(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Medali gradien aksen — wajah tiap layar kosong.
              // Identitas v1.28: gradient + glow dari token (satu sumber).
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: medal,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glow(context),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CategoryGlyph.iconFor(icon),
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
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
      ),
    );
  }
}
