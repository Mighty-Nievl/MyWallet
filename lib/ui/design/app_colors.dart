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

  /// Lebar border kartu — 1.5px di dark agar batas kartu (#111 vs #0A0A0A)
  /// tetap effortless terbaca; 1px cukup di light (putih vs #FAFAFA).
  /// B2C v1.24.2 (kritik brutal: kartu dark nyaris lebur).
  static double borderWidthOf(BuildContext context) =>
      isDark(context) ? 1.5 : 1;

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
  // Masuk = hijau tetap, keluar = error tema. Dipakai Beranda (hero +
  // strip hari ini), tile transaksi, dst — jadi tidak ada dua palet
  // hijau/merah yang berbeda kadar dalam satu layar.
  //
  // Pemasukan SENGAJA tidak ikut aksen tema: bila user memilih aksen
  // merah/oranye, "Masuk = primary" akan sama persis dengan "Keluar =
  // error" (v1.13.x). Hijau tetap lolos WCAG ≥4.5:1 di kedua tema
  // (diuji di home_design_test), aksen tetap dipakai untuk brand
  // (ikon, bar kategori, hero, FAB).

  /// Pemasukan di atas permukaan biasa (kartu terang / dark mode).
  static Color incomeOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

  /// Pengeluaran di atas permukaan biasa.
  static Color expenseOf(BuildContext context) =>
      Theme.of(context).colorScheme.error;
}
