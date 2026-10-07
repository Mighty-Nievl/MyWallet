import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';

/// Ikon kategori di kotak subtle — dipakai TxTile & Beranda.
///
/// Netral (tidak ikut warna aksen) agar list tetap tenang dibaca.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.icon,
    this.size = 40,
    this.fontSize = 20,
  });

  final String icon;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.subtleOf(context),
        borderRadius: AppRadius.mdAll,
      ),
      alignment: Alignment.center,
      child: Text(icon, style: TextStyle(fontSize: fontSize)),
    );
  }
}
