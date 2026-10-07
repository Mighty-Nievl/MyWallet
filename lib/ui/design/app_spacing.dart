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

  /// Jarak judul section ke kontennya.
  static const double groupGap = s12;

  /// Padding dalam kartu.
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);
}
