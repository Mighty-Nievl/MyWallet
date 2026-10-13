import 'package:flutter/material.dart';

// Gradien cair pastel vibrant — identitas visual MyWallet (v1.28).
//
// Aturan pakai:
// - JANGAN bikin LinearGradient/RadialGradient manual di layar —
//   pakai [MeshGradient] (widget) atau helper di sini.
// - Warna diambil dari [ColorScheme] aktif agar ikut aksen user.
// - Teks di atas mesh WAJIB putih + lolos WCAG >= 4.5:1 (dikunci test).
// - Mesh = 2-3 RadialGradient ditumpuk (murah di HP kentang).
abstract final class AppGradients {
  // Blob mesh untuk hero — 3 warna SEKELUARGA dengan hue digeser
  // (+30 / -35 / +60 derajat, lightness naik dikit +0.04).
  // Terukur 6 aksen x 2 tema: blend alpha 0.35 di atas [heroBase]
  // vs putih >= 4.5:1 (terendah 4.9:1). Dikunci
  // test/visual_identity_test.dart. JANGAN naikkan lift/alpha
  // tanpa hitung ulang — lift murni +0.10 jebol ke 4.2:1.
  static List<Color> heroBlobs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final lift = isDark ? 0.08 : 0.04;
    Color blob(Color c, double deg) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withHue(((hsl.hue + deg) % 360 + 360) % 360)
          .withLightness((hsl.lightness + lift).clamp(0.0, 1.0))
          .toColor();
    }

    return [
      blob(scheme.primary, 30),
      blob(scheme.secondary, -35),
      blob(scheme.tertiary, 60),
    ];
  }

  // Dasar hero — primary digelapkan agar teks putih kontras >= 4.5:1.
  // Terukur 6 aksen: light L=0.26 (terendah teal 5.2:1), dark L=0.22.
  // Jangan naikkan tanpa hitung ulang.
  static Color heroBase(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (scheme.brightness == Brightness.dark) {
      return HSLColor.fromColor(scheme.primary).withLightness(0.22).toColor();
    }
    return HSLColor.fromColor(scheme.primary).withLightness(0.26).toColor();
  }

  // Medali empty-state — gradien aksen diagonal.
  static List<Color> medal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primary,
      Color.lerp(scheme.primary, scheme.primaryContainer, 0.45)!,
    ];
  }

  // Glow warna aksen untuk bayangan tombol/lingkaran (bukan hitam).
  static Color glow(BuildContext context, {double alpha = 0.28}) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: alpha);
  }
}
