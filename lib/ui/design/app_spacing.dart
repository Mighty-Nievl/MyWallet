import 'package:flutter/widgets.dart';

/// Skala spacing konsisten. Pakai salah satu nilai ini —
/// hindari angka arbitrer (13, 17, 23, ...) tanpa alasan kuat.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// Padding horizontal halaman.
  static const double page = s16;

  /// Jarak antar section besar (saldo -> harian -> kategori -> riwayat).
  static const double sectionGap = s24;

  /// Jarak antar section LEGA ala B2C (Beranda v1.24+: hero→monthnav→seksi).
  /// B2C v1.24.2: token resmi, bukan literal 32 tersebar.
  static const double sectionGapLarge = s32;

  /// Jarak judul section ke kontennya.
  static const double groupGap = s12;

  /// Padding dalam kartu.
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);

  /// Padding dalam kartu BESAR (hero saldo): lega 24.
  /// B2C v1.24.2: hero pakai ini, bukan literal all(24).
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(s24);

  /// Ruang kosong selebar FAB + margin notch (56 + 2×8).
  /// Tanpa ini tab Budget/Laporan ketindih cekungan (legacy BottomAppBar).
  /// M3 NavigationBar tidak butuh ini — dipertahankan untuk kompatibilitas.
  static const double navFabGap = 72;

  /// Tinggi bar navigasi custom legacy (M3 NavigationBar atur sendiri).
  static const double navBarHeight = 56;

  /// Ruang napas bawah agar konten terakhir tidak tertutup FAB + bar.
  static const double bottomPad = 96;

  /// Target sentuh minimum Material (48×48).
  static const double touchMin = 48;
}
