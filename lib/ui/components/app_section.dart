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
    final titleWidget = Text(title, style: AppType.sectionTitle(context));
    final t = trailing;
    // v1.46 (Dynamic Type): pada teks ≥1.6× tombol trailing ("Semua
    // catatan") bisa lebih lebar dari sisa baris, menekan judul sampai
    // 0px — terukur overflow 95px (375) / 150px (320) di Beranda.
    // Di skala besar, trailing turun ke baris sendiri; judul dapat
    // lebar penuh dan tombol boleh wrap.
    final stackTrailing =
        t != null && MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t == null)
          titleWidget
        else if (stackTrailing) ...[
          titleWidget,
          const SizedBox(height: AppSpacing.micro),
          t,
        ] else
          Row(
            children: [
              Expanded(child: titleWidget),
              t,
            ],
          ),
        const SizedBox(height: AppSpacing.groupGap),
        child,
      ],
    );
  }
}
