import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';

/// Tombol ikon kotak berboder — SATU-SATUNYA cara bikin tombol ikon
/// kotak di seluruh aplikasi (header, form, kembali, kalender, mata).
///
/// Menggantikan 9 duplikat manual `BorderRadius.circular(10)` yang
/// melanggar token (AppRadius cuma punya 8/12/14).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  /// `true` = isi aksen (untuk aksi utama semacam "Catat").
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (filled) {
      return IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.touchMin,
            AppSpacing.touchMin,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(
          width: AppSpacing.touchMin,
          height: AppSpacing.touchMin,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: color ?? scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
        ),
      ),
    );
  }
}

/// Kebutuhan error ramah: pesan manusia + tombol coba lagi.
/// Menggantikan `Text('Error: $e')` mentah (pesan developer, bukan UI).
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Gagal memuat.',
    this.subtitle = 'Periksa lagi sebentar.',
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.mutedOf(context),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedOf(context)),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton shimmer: pengganti `LinearProgressIndicator` indeterminate
/// yang kebaca sebagai bug loading. Bar abu statis berdenyut halus.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.lines = 3, this.height = 14});

  final int lines;
  final double height;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.subtleOf(context);
    return Column(
      children: List.generate(
        widget.lines,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: FadeTransition(
            opacity: Tween(begin: 0.5, end: 1.0).animate(_ctrl),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: base,
                borderRadius: AppRadius.smAll,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
