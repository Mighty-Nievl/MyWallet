// Kunci identitas visual v1.28 (mesh cair + floating + pill).
//
// - Mesh: teks putih di atas base + di atas blend blob HARUS >= 4.5:1
//   di 6 aksen x 2 tema (matematika tema murni, tanpa pump).
// - Audit: tidak ada BoxShadow hitam pekat (>0.30) di komponen shared,
//   tidak ada radius literal (999/12/...) di layar/komponen — semua
//   wajib dari AppRadius.
// - Setelah Navigator.push, teks ganda di dua route → pakai finder
//   type-qualified bila perlu (pelajaran v1.27).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/design/app_gradients.dart';
import 'package:mywallet/ui/design/app_radius.dart';
import 'package:mywallet/ui/design/app_shadows.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _ratio(Color a, Color b) {
  final hi = max(_lum(a), _lum(b));
  final lo = min(_lum(a), _lum(b));
  return (hi + 0.05) / (lo + 0.05);
}

/// Alpha blend manual (mirror MeshGradient._blob alpha 0.35).
/// Harus diubah bareng bila alpha blob berubah.
Color _blend(Color top, double alpha, Color bottom) {
  double ch(double t, double b) => t * alpha + b * (1 - alpha);
  return Color.from(
    alpha: 1,
    red: ch(top.r, bottom.r),
    green: ch(top.g, bottom.g),
    blue: ch(top.b, bottom.b),
  );
}

void main() {
  // Mesh: putih vs dasar hero >= 4.5:1 (semua aksen x 2 tema).
  testWidgets('mesh: putih vs dasar hero minimal 4.5:1 (semua aksen)', (
    tester,
  ) async {
    final hasil = <String, double>{};
    for (final e in AppTheme.accentOptions.entries) {
      for (final mode in ['light', 'dark']) {
        final theme = mode == 'light'
            ? AppTheme.light(seed: e.value.color)
            : AppTheme.dark(seed: e.value.color);
        late Color base;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (ctx) {
                base = AppGradients.heroBase(ctx);
                return const SizedBox();
              },
            ),
          ),
        );
        hasil['${e.key}/$mode base'] = _ratio(Colors.white, base);
      }
    }
    hasil.forEach(
      (label, r) => expect(r, greaterThanOrEqualTo(4.5), reason: label),
    );
    final worst = hasil.entries.reduce((a, b) => a.value < b.value ? a : b);
    debugPrint(
      'mesh base minimum ${worst.value.toStringAsFixed(2)}:1 '
      '(${worst.key}) — ${hasil.length} pengukuran lolos >=4.5:1',
    );
  });

  // Mesh: putih vs BLEND blob (alpha 0.35) >= 4.5:1 — kasus terburuk
  // adalah area blob, bukan dasar polos.
  testWidgets('mesh: putih vs blend blob minimal 4.5:1 (semua aksen)', (
    tester,
  ) async {
    final hasil = <String, double>{};
    for (final e in AppTheme.accentOptions.entries) {
      for (final mode in ['light', 'dark']) {
        final theme = mode == 'light'
            ? AppTheme.light(seed: e.value.color)
            : AppTheme.dark(seed: e.value.color);
        late Color base;
        late List<Color> blobs;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (ctx) {
                base = AppGradients.heroBase(ctx);
                blobs = AppGradients.heroBlobs(ctx);
                return const SizedBox();
              },
            ),
          ),
        );
        for (var i = 0; i < blobs.length; i++) {
          hasil['${e.key}/$mode blob$i'] = _ratio(
            Colors.white,
            _blend(blobs[i], 0.35, base),
          );
        }
      }
    }
    hasil.forEach(
      (label, r) => expect(r, greaterThanOrEqualTo(4.5), reason: label),
    );
    final worst = hasil.entries.reduce((a, b) => a.value < b.value ? a : b);
    debugPrint(
      'mesh blend minimum ${worst.value.toStringAsFixed(2)}:1 '
      '(${worst.key}) — ${hasil.length} pengukuran lolos >=4.5:1',
    );
  });

  // Audit: shadow kartu lembut — alpha hitam kartu <= 0.30, floating
  // aksen <= 0.35 (bukan hitam pekat). Ukur token langsung via context
  // tema asli (bukan eyeball).
  testWidgets('audit: shadow kartu lembut, bukan hitam pekat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) {
            for (final s in AppShadows.card(ctx)) {
              expect(
                s.color.a,
                lessThanOrEqualTo(0.30),
                reason: 'shadow kartu pekat: ${s.color}',
              );
              expect(
                s.blurRadius,
                greaterThanOrEqualTo(20),
                reason: 'shadow kartu kurang menyebar',
              );
            }
            for (final s in AppShadows.floating(ctx)) {
              expect(
                s.color.a,
                lessThanOrEqualTo(0.35),
                reason: 'shadow floating pekat: ${s.color}',
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  });

  // Audit: token pill + kartu + thumb ada dan bernilai benar.
  // Menangkap regresi "token diubah diam-diam".
  test('audit: token radius pill + kartu + thumb terkunci', () {
    expect(AppRadius.pill, 999);
    expect(AppRadius.card, 24);
    expect(AppRadius.thumb, 16);
  });
}
