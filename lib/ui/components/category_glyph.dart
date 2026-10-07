import 'package:flutter/material.dart';

import '../design/app_radius.dart';

/// Glyph kategori monochrome/duotone — pengganti emoji di list transaksi.
///
/// Data emoji di DB TIDAK diubah (kompatibel mundur). Widget ini hanya
/// memetakan emoji yang dikenal ke [IconData] Material outlined,
/// digambar monochrome dengan warna aksen ([ColorScheme.primary])
/// di atas permukaan tonal. Emoji custom yang tidak dikenal jatuh
/// ke ikon generik — tidak pernah crash, tidak pernah ada kotak kosong.
///
/// Dipakai: TxTile (Beranda + Riwayat) & daftar top kategori Beranda.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.emoji,
    this.size = 40,
    this.iconSize = 20,
  });

  /// String emoji mentah dari DB (`Category.icon`, `TxWithCategory.catIcon`).
  final String emoji;
  final double size;
  final double iconSize;

  /// Peta emoji bawaan (seed `defaultCategories`) + ikon sistem.
  static IconData iconFor(String emoji) {
    final e = emoji.trim();
    // Cocokkan substring agar variasi selector (️, VS16) tetap kena.
    if (e.contains('🍔')) return Icons.restaurant_outlined;
    if (e.contains('🛵')) return Icons.directions_bike_outlined;
    if (e.contains('🛍')) return Icons.shopping_bag_outlined;
    if (e.contains('🧾')) return Icons.receipt_long_outlined;
    if (e.contains('💊')) return Icons.medication_outlined;
    if (e.contains('🎮')) return Icons.sports_esports_outlined;
    if (e.contains('📚') || e.contains('📖')) return Icons.school_outlined;
    if (e.contains('💰')) return Icons.payments_outlined;
    if (e.contains('🎁')) return Icons.card_giftcard_outlined;
    if (e.contains('🏪') || e.contains('🏬')) return Icons.store_outlined;
    if (e.contains('📥') || e.contains('📤')) return Icons.inbox_outlined;
    if (e.contains('📅') || e.contains('📆')) {
      return Icons.calendar_today_outlined;
    }
    if (e.contains('📦')) return Icons.inventory_2_outlined;
    if (e.contains('💸') || e.contains('💵')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (e.contains('📈') || e.contains('💹')) {
      return Icons.trending_up_outlined;
    }
    if (e.contains('📉')) return Icons.trending_down_outlined;
    if (e.contains('🚌') || e.contains('🚗')) {
      return Icons.directions_bus_outlined;
    }
    if (e.contains('📖')) return Icons.menu_book_outlined;
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.12),
      scheme.surface,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tile,
        borderRadius: AppRadius.mdAll,
      ),
      alignment: Alignment.center,
      child: Icon(
        iconFor(emoji),
        size: iconSize,
        color: scheme.primary,
        semanticLabel: emoji,
      ),
    );
  }
}
