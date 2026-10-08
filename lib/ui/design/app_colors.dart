import 'package:flutter/material.dart';

/// Token warna netral ala shadcn: restrained, subtle, profesional.
///
/// Aturan pakai:
/// - Latar/permukaan/border netral dari sini.
/// - Aksen (primary), error, dan warna semantik LAIN tetap dari
///   [ColorScheme] aplikasi (sistem aksen + Material You tidak terganggu).
/// - Jangan hard-code putih/hitam di komponen — pakai helper di bawah
///   atau [Theme.of] agar dark mode + true black tetap benar.
abstract final class AppColors {
  // ---- Light ----
  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSubtle = Color(0xFFF5F5F5);
  static const lightBorder = Color(0xFFE5E5E5);

  // ---- Dark ----
  static const darkBackground = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF111111);
  static const darkSubtle = Color(0xFF181818);
  static const darkBorder = Color(0xFF262626);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Border halus untuk kartu / tombol ikon / pembatas.
  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  /// Permukaan sekunder (track progress, tile ikon netral, dsb).
  static Color subtleOf(BuildContext context) =>
      isDark(context) ? darkSubtle : lightSubtle;

  /// Permukaan kartu — ikut [CardTheme] agar true black tetap benar.
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surface;

  /// Teks sekunder di atas permukaan.
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Teks sekunder KONTRAS TINGGI (abu-abu gelap di light, abu terang
  /// di dark) — untuk tanggal/deskripsi list transaksi agar mudah dibaca.
  /// Lebih gelap dari [mutedOf], tapi tetap di bawah judul (hierarki
  /// dijaga via ukuran + weight, bukan cuma warna).
  static Color strongSecondaryOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF424242);

  // ---- Semantik nominal (satu sumber kebenaran) ----
  // Masuk = aksen tema, keluar = error tema. Dipakai Beranda (hero +
  // strip hari ini), tile transaksi, dst — jadi tidak ada dua palet
  // hijau/merah yang berbeda kadar dalam satu layar.

  /// Pemasukan di atas permukaan biasa (kartu terang / dark mode).
  static Color incomeOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Pengeluaran di atas permukaan biasa.
  static Color expenseOf(BuildContext context) =>
      Theme.of(context).colorScheme.error;
}
