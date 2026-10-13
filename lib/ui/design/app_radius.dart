import 'package:flutter/widgets.dart';

/// Radius ramah — pill untuk tombol/chip, besar untuk kartu (v1.28).
/// kecil: ikon/indicator · sedang: tile/list · besar: kartu melayang.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;

  /// Radius "kartu besar" ala mockup: banner 16, kartu saldo 20.
  static const double xl = 16;
  static const double xxl = 20;

  /// Kartu melayang identitas baru (v1.28): 24 — lega + modern.
  /// Token BARU (nilai lama tak diubah agar tak bocor ke 10+ layar).
  static const double card = 24;

  /// Thumbnail konsisten (v1.28): 16 di semua list.
  static const double thumb = 16;

  /// Bentuk kapsul penuh — tombol, search, chip, tag (v1.28).
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius thumbAll = BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
