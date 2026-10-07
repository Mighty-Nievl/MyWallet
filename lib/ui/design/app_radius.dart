import 'package:flutter/widgets.dart';

/// Radius restrained — tidak semuanya pil.
/// kecil: ikon/indicator · sedang: tile/list · besar: kartu.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
