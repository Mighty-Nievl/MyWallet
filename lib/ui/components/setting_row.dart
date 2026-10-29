import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_feedback.dart';

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
    final titleColor = destructive ? scheme.error : null;
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
              // v1.30 (karakteristik #3+#5): thumbnail konsisten ikut
              // token thumb (dulu md = beda sendiri vs glyph lain).
              borderRadius: AppRadius.thumbAll,
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.micro),
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
            // v1.45 (Dynamic Type): trailing dibatasi 42% lebar layar.
            // Tanpa ini, nilai panjang ("5 transaksi") pada teks 2×
            // mendorong Row melebihi lebar — terukur overflow 15px di
            // 320px (probe `settings_ui_contract_test`).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.42,
              ),
              child: trailing,
            ),
          ] else if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s8),
            const SettingChevron(),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    final tap = onTap!;
    return InkWell(
      // B2C v1.20: haptic di SEMUA baris pengaturan (sekali sentuh di
      // sini = kena Settings + Kategori + Keluarga + semua sub-halaman).
      onTap: () {
        HapticFeedback.selectionClick();
        tap();
      },
      borderRadius: AppRadius.mdAll,
      child: content,
    );
  }
}

/// Baris dengan switch — pola yang dulu disalin 12×: `Switch(onChanged:)`
/// plus `onTap` yang membalik nilai. Dua affordance, satu sumber.
///
/// [value] sudah diresolusi pemanggil (bukan AsyncValue) supaya komponen
/// tetap murni dan bisa dites tanpa container Riverpod.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      destructive: destructive,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
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
            // 2 baris: pada teks 2× nilai seperti "5 transaksi" pecah
            // jadi dua baris, bukan terpotong "5 tran…".
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
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
          // v1.45: left 4 → 0. Label grup duduk di rail halaman (x=16),
          // bukan x=20 — sama dengan judul section Beranda (v1.42).
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Text(
            title,
            style: AppType.groupLabel(
              context,
            ).copyWith(color: titleColor ?? scheme.primary),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                // v1.45: 52 → 64 = 12 (padding baris) + 40 (kotak ikon) +
                // 12 (gap) — divider mulai tepat di kolom teks, bukan di
                // tengah ikon.
                if (i > 0) const Divider(height: 1, indent: 64),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Header sub-halaman: tombol kembali polos + judul besar.
/// Bahasa yang sama dengan header custom STEP 1-3.
///
/// v1.24.7: tombol kembali via AppIconButton shared (48px + haptic,
/// bukan manual 40px) — satu keluarga dengan AppHeader.
/// v1.30.1: kembali = polos tanpa border (permintaan user 2026-10-13) —
/// samakan dengan tombol header lain (gear/chevron/mata).
/// [actions]: tombol aksi trailing opsional (form Catat: scan + hapus).
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Kembali',
          onPressed: () => Navigator.maybePop(context),
          // v1.30.1: tombol kembali polos (tanpa border) — permintaan
          // user 2026-10-13, samakan dgn tombol header lain.
          bordered: false,
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
        for (final a in actions) ...[const SizedBox(width: AppSpacing.s8), a],
      ],
    );
  }
}
