import 'package:flutter/material.dart';

/// Tema Material 3 MyWallet: seed warna aksen + varian gelap/hitam pekat.
///
/// Dibuat dari seed agar seluruh varian (terang/gelap) konsisten,
/// atau dari [ColorScheme] dinamis (Material You) via [fromScheme].
class AppTheme {
  /// Pilihan warna aksen: nama -> (label, warna).
  static const accentOptions = <String, ({String label, Color color})>{
    'green': (label: 'Hijau Dompet', color: Color(0xFF0E7C5B)),
    'blue': (label: 'Biru', color: Color(0xFF2563EB)),
    'purple': (label: 'Ungu', color: Color(0xFF7C3AED)),
    'orange': (label: 'Oranye', color: Color(0xFFEA580C)),
    'red': (label: 'Merah', color: Color(0xFFDC2626)),
    'teal': (label: 'Toska', color: Color(0xFF0D9488)),
  };

  static const _defaultSeed = Color(0xFF0E7C5B);

  /// Seed aman dari nama (fallback hijau bila nama tak dikenal).
  static Color seedFor(String name) =>
      accentOptions[name]?.color ?? _defaultSeed;

  static ThemeData light({Color seed = _defaultSeed, bool compact = false}) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return _build(scheme, compact: compact);
  }

  static ThemeData dark({
    Color seed = _defaultSeed,
    bool trueBlack = false,
    bool compact = false,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _build(scheme, trueBlack: trueBlack, compact: compact);
  }

  /// Tema dari skema dinamis (Material You). [trueBlack] hanya untuk dark.
  static ThemeData fromScheme(
    ColorScheme scheme, {
    bool trueBlack = false,
    bool compact = false,
  }) =>
      _build(scheme, trueBlack: trueBlack, compact: compact);

  static ThemeData _build(
    ColorScheme scheme, {
    bool trueBlack = false,
    bool compact = false,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final useBlack = isDark && trueBlack;
    final effective = useBlack ? scheme.copyWith(surface: Colors.black) : scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: effective,
      scaffoldBackgroundColor: useBlack ? Colors.black : null,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: useBlack ? const Color(0xFF121212) : null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
