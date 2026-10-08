import 'package:flutter/widgets.dart';

/// Radius restrained — tidak semuanya pil.
/// kecil: ikon/indicator · sedang: tile/list · besar: kartu.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;

  /// Radius "kartu besar" ala mockup: banner 16, kartu saldo 20.
  static const double xl = 16;
  static const double xxl = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
}
