import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'design/app_colors.dart';
import 'design/app_radius.dart';

/// Tema Material 3 MyWallet: seed warna aksen + varian gelap/hitam pekat.
///
/// Dibuat dari seed agar seluruh varian (terang/gelap) konsisten,
/// atau dari [ColorScheme] dinamis (Material You) via [fromScheme].
///
/// Visual identitas v1.28 (mesh cair + floating + pill): latar netral,
/// kartu radius 24 + bayangan lembut menyebar, tombol/chip/search pill
/// penuh, dialog/sheet kartu 24. Fungsionalitas lama (aksen, dynamic,
/// true black, compact, font scale) TIDAK berubah.
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
  }) => _build(scheme, trueBlack: trueBlack, compact: compact);

  static ThemeData _build(
    ColorScheme scheme, {
    bool trueBlack = false,
    bool compact = false,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final useBlack = isDark && trueBlack;
    final effective = useBlack
        ? scheme.copyWith(surface: Colors.black)
        : scheme;
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
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      // B2C v1.20: transisi halaman fade-through konsisten di semua
      // platform (bukan slide Android bawaan yang kasar).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
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
        // Identitas v1.28: kartu radius 24 ramah + border tipis.
        // Shadow melayang milik AppCard custom (bukan Card material).
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      // Semua kolom input (cari, nominal, catatan, dropdown, PIN, dialog)
      // satu gaya: pill ramah + border subtle, fokus pakai aksen (v1.28).
      // Widget TIDAK perlu set border manual — cukup InputDecoration biasa.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.pillAll,
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      // Tombol identitas v1.28: kapsul penuh di semua varian.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        ),
      ),
      // Dialog + bottom sheet: kartu 24 ramah (v1.28).
      dialogTheme: DialogThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
        showDragHandle: true,
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      ),
    );
  }
}
