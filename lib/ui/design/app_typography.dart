import 'package:flutter/material.dart';

/// Hierarki tipografi MyWallet.
///
/// - Judul layar: besar + semibold (header Beranda).
/// - Judul section: sedang + semibold.
/// - Nominal: besar/tegas hanya untuk saldo & jumlah transaksi.
/// - Sekunder: kecil + muted.
/// - Jangan semua-bold. Font scaling global (MediaQuery textScaler)
///   tetap dihormati karena ukuran di sini ikut diskala sistem.
abstract final class AppType {
  /// Judul layar ("MyWallet").
  static TextStyle screenTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 22);
    return base.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    );
  }

  /// Judul section ("Hari ini", "Pengeluaran bulan ini", ...).
  static TextStyle sectionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16);
    return base.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    );
  }

  /// Nominal saldo — elemen visual terkuat di Beranda.
  static TextStyle balance(BuildContext context) =>
      const TextStyle(fontSize: 32, fontWeight: FontWeight.w700);

  /// Nominal baris transaksi / ringkasan: penting tapi tidak raksasa.
  static TextStyle amount(BuildContext context, {double size = 15}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w700);

  /// Label kecil di atas nominal ("Pemasukan", "Saldo saat ini", ...).
  static TextStyle labelMuted(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// Teks sekunder satu baris ("Makanan · Hari ini").
  static TextStyle secondary(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12);
    return base.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
