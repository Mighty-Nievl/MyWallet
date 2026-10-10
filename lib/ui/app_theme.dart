import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'design/app_colors.dart';
import 'design/app_radius.dart';

/// Tema Material 3 MyWallet: seed warna aksen + varian gelap/hitam pekat.
///
/// Dibuat dari seed agar seluruh varian (terang/gelap) konsisten,
/// atau dari [ColorScheme] dinamis (Material You) via [fromScheme].
///
/// Visual (STEP 1, ala shadcn): latar netral restrained, kartu subtle
/// + border tipis tanpa shadow, radius restrained (kartu 14, input 12).
/// Fungsionalitas lama (aksen, dynamic, true black, compact, font scale)
/// TIDAK berubah — hanya fondasi visual yang dirapikan.
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
    // Latar netral restrained (bukan surface bawaan M3 yang kebiruan).
    final bg = useBlack
        ? Colors.black
        : isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground;
    final border = useBlack
        ? AppColors.darkBorder
        : isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder;
    return ThemeData(
      useMaterial3: true,
      colorScheme: effective,
      scaffoldBackgroundColor: bg,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      // B2C v1.20: transisi halaman fade-through konsisten di semua
      // platform (bukan slide Android bawaan yang kasar).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows:
              FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: useBlack
            ? const Color(0xFF121212)
            : isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
        // Subtle: border tipis netral, tanpa shadow.
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      // Semua kolom input (cari, nominal, catatan, dropdown, PIN, dialog)
      // satu gaya: radius 12 + border subtle, fokus pakai aksen.
      // Widget TIDAK perlu set border manual — cukup InputDecoration biasa.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
