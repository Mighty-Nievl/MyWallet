import 'package:flutter/material.dart';

// Bayangan lembut menyebar — identitas visual MyWallet (v1.28).
//
// Aturan:
// - TIDAK ada shadow hitam pekat (alpha > 0.3 dilarang di kartu).
// - Kartu = hitam 8% blur 24 offset y8 (light) / 28% di dark.
// - Melayang (hero saldo, bottom nav) = aksen 28-35% blur 24-32.
// - Satu sumber: layar dilarang bikin BoxShadow manual — pakai ini.
abstract final class AppShadows {
  // Kartu standar — terangkat lembut, bukan flat, bukan pekat.
  static List<BoxShadow> card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  // Kartu melayang (hero saldo, bottom nav) — blur lebih lebar.
  static List<BoxShadow> floating(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.28),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  // Glow tombol solid (tombol tengah nav, CTA hero).
  static List<BoxShadow> glow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      BoxShadow(
        color: scheme.primary.withValues(alpha: 0.35),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // Dock navigasi bawah (kapsul 232x56) — bayangan RAMPING khusus dock.
  // v1.32.5: floating() (blur 32, offset 12) boros untuk kapsul 56
  // (rasio >50%, kabut ke bawah tak terlihat gunanya, audit piksel:
  // tak ada gradasi di atas dock tapi bobot render sia-sia). blur 20 +
  // offset 4 = angkat lembut proporsional, SCOPED (jangan ubah
  // floating(): dipakai hero saldo + MeshGradient default).
  static List<BoxShadow> dock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.primary.withValues(alpha: isDark ? 0.30 : 0.22),
        blurRadius: 20,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
        blurRadius: 16,
        offset: const Offset(0, 3),
        spreadRadius: 0,
      ),
    ];
  }
}
