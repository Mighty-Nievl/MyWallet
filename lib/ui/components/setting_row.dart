import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Bahasa baris pengaturan STEP 4 — dipakai semua halaman settings +
/// kategori. Satu gaya: ikon kotak subtle + judul + deskripsi +
/// kontrol trailing. Bukan giant card per baris.
///
/// [trailing] opsional — bila null dan [onTap] ada, tampil chevron.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor =
        destructive ? scheme.error : null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: destructive
                  ? scheme.errorContainer
                  : AppColors.subtleOf(context),
              borderRadius: AppRadius.mdAll,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: destructive
                  ? scheme.onErrorContainer
                  : AppColors.mutedOf(context),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppType.secondary(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s8),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s8),
            const SettingChevron(),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: content,
    );
  }
}

/// Chevron standar untuk baris navigasi.
class SettingChevron extends StatelessWidget {
  const SettingChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right,
      size: 20,
      color: AppColors.mutedOf(context),
    );
  }
}

/// Nilai trailing + chevron, mis. "Ikuti HP  >".
class SettingValue extends StatelessWidget {
  const SettingValue({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            style: AppType.secondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        const SettingChevron(),
      ],
    );
  }
}

/// Grup pengaturan: label kecil + wadah subtle berisi baris-baris
/// dengan divider otomatis. Tidak perlu atur divider manual —
/// cukup oper list [children].
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: 4, bottom: AppSpacing.s8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: titleColor ?? scheme.primary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 52),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Header sub-halaman: tombol kembali berboder + judul besar.
/// Bahasa yang sama dengan header custom STEP 1-3.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
                color: AppColors.borderOf(context)),
          ),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Kembali',
            constraints: const BoxConstraints.tightFor(
                width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppType.screenTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
