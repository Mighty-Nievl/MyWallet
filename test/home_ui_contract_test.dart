// Kontrak UI Beranda (v1.46) — hasil audit `ui-ux-pro-max`.
//
// Yang dikunci:
// 1. Target sentuh chip periode & tombol kalender ≥48dp Android.
//    Sebelumnya `SizedBox(height: 44)` memotong tap-target Material.
// 2. Tidak ada overflow pada teks 2× di 375 & 320 (light + dark).
//    Sebelumnya header `AppSection` menekan judul sampai 0px dan
//    baris Top kategori mendorong nominal keluar layar (95px / 150px).
// 3. Kontras teks sekunder di dark ≥4.5:1 (diukur, bukan diasumsikan).
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/design/app_colors.dart';
import 'package:mywallet/ui/shell.dart';

Future<AppDatabase> _db(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final db = await t.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.customSelect('SELECT 1').get();
    await d.backfillAccounts();
    return d;
  });
  return db!;
}

Future<void> _seed(WidgetTester t, AppDatabase db) async {
  await t.runAsync(() async {
    final accounts = await db.select(db.accounts).get();
    final id = accounts.firstWhere((a) => a.name == 'Utama').id;
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 8925000 - i * 15000,
              isExpense: Value(i.isEven),
              categoryId: Value((i % 8) + 1),
              date: DateTime(now.year, now.month, now.day - (i ~/ 4)),
              note: Value('Jajan $i'),
              accountId: Value(id),
            ),
          );
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  double width = 390,
  double scale = 1.0,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _cleanup(WidgetTester tester, AppDatabase db) async {
  try {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => db.close());
  } catch (_) {}
}

double _lum(Color c) {
  double ch(double v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(c.r * 255) +
      0.7152 * ch(c.g * 255) +
      0.0722 * ch(c.b * 255);
}

double _ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('target sentuh periode & kalender ≥48', (tester) async {
    final db = await _db(tester);
    try {
      await _seed(tester, db);
      await _pump(tester, db);

      final chip = tester.getSize(
        find.byKey(const ValueKey('period:kind:bulanan')),
      );
      expect(chip.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byKey(const ValueKey('period:calendar'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('period:prev'))).height,
        greaterThanOrEqualTo(48),
      );
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('teks 2×: tidak overflow di 375 & 320, light + dark', (
    tester,
  ) async {
    final db = await _db(tester);
    try {
      await _seed(tester, db);

      for (final width in [375.0, 320.0]) {
        for (final dark in [false, true]) {
          await _pump(tester, db, width: width, scale: 2.0, dark: dark);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow ${width}px/2×/${dark ? 'dark' : 'light'}',
          );
          // Judul section harus tetap punya lebar (tidak ditekan ke 0).
          final title = find.textContaining('Terakhir dicatat');
          expect(tester.getSize(title.first).width, greaterThan(0));
        }
      }
    } finally {
      await _cleanup(tester, db);
    }
  });

  test('kontras teks sekunder dark & light ≥4.5:1', () {
    final dark = AppTheme.dark().colorScheme;
    final light = AppTheme.light().colorScheme;
    final dSurf = AppColors.darkSurface;
    final lSurf = AppColors.lightSurface;

    expect(_ratio(dark.onSurfaceVariant, dSurf), greaterThan(4.5));
    expect(_ratio(dark.onSurface, dSurf), greaterThan(4.5));
    expect(_ratio(light.onSurfaceVariant, lSurf), greaterThan(4.5));
    // Angka terukur (audit 29 Okt): 11.10 / 14.62 / 9.31 — jauh di atas AA.
  });
}
