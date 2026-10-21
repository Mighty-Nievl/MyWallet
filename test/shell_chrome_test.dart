// Regression v1.33.1 — audit UI/UX kapsul FAB (shell).
//
// Kontrak yang dikunci (semua lahir dari overlay kapsul di slot FAB):
// - P1: badan Beranda punya scrim gradient turun (key `home:scrim`) yang
//   TIDAK menelan tap (IgnorePointer) → teks memudar sebelum kena tepi
//   kapsul, bukan terpotong border.
// - P2: isi kapsul hidup di dalam Material berwarna surface (host ripple).
//   Dulu warna opaque ada di Container DI ATAS Material Scaffold, jadi
//   splash InkWell tak pernah terlihat.
// - P5: label chrome tidak overflow di textScaler 2.0 (di-clamp 1.3 +
//   ellipsis), karena slot label cuma ±77px lebar.
// - P7: kapsul tuck saat scroll turun dan kembali setelah scroll berhenti.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/shell.dart';

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.customSelect('SELECT 1').get();
    await d.backfillAccounts();
    return d;
  });
  return db!;
}

Future<void> _pump(WidgetTester tester, {int ticks = 30}) async {
  for (var i = 0; i < ticks; i++) {
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

Future<void> _seed(WidgetTester tester, AppDatabase db) async {
  await tester.runAsync(() async {
    final utama = (await db.select(db.accounts).get())
        .firstWhere((a) => a.name == 'Utama')
        .id;
    final now = DateTime.now();
    for (var i = 0; i < 14; i++) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 50000 + i * 1000,
              isExpense: Value(i.isEven),
              categoryId: Value((i % 8) + 1),
              date: DateTime(now.year, now.month, now.day - (i ~/ 4)),
              note: Value('Isi $i'),
              accountId: Value(utama),
            ),
          );
    }
  });
}

Widget _app(AppDatabase db, {TextScaler? scaler}) {
  return ProviderScope(
    overrides: [dbProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: scaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
      home: const AppShell(),
    ),
  );
}

void main() {
  testWidgets('scrim bawah ada & tidak menelan tap (v1.33.1 P1)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(_app(db));
      await _pump(tester);
      final scrim = find.byKey(const ValueKey('home:scrim'));
      expect(scrim, findsOneWidget);
      // Scrim harus di bawah kapsul (body) dan lebar penuh.
      final scrimRect = tester.getRect(scrim);
      expect(scrimRect.width, closeTo(390.0, 0.5));
      expect(scrimRect.bottom, closeTo(844.0, 0.5));
      final guard = tester.widget<IgnorePointer>(
        find
            .ancestor(of: scrim, matching: find.byType(IgnorePointer))
            .first,
      );
      expect(guard.ignoring, isTrue, reason: 'scrim tak boleh blokir tap');
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('kapsul punya host ripple Material sendiri (v1.33.1 P2)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(_app(db));
      await _pump(tester);
      final capsule = find.byKey(const ValueKey('home:navbar'));
      final materials = find.descendant(
        of: capsule,
        matching: find.byType(Material),
      );
      expect(materials, findsWidgets);
      final host = tester.widget<Material>(materials.first);
      // Warna surface harus di Material (host ink), bukan di Container
      // opaque di atasnya — kalau tidak, ripple tertutup.
      expect(host.color, AppTheme.light().colorScheme.surface);
      expect(host.clipBehavior, Clip.antiAlias);
      expect(
        find.descendant(of: capsule, matching: find.byType(InkWell)),
        findsNWidgets(2),
      );
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('label kapsul tidak overflow di textScaler 2.0 (v1.33.1 P5)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(_app(db, scaler: const TextScaler.linear(2.0)));
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      // Kapsul tetap 232×56 walau font HP besar.
      final rect = tester.getRect(find.byKey(const ValueKey('home:navbar')));
      expect(rect.width, lessThanOrEqualTo(232.0));
      expect(rect.height, lessThanOrEqualTo(56.0));
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('kapsul tuck saat scroll turun, kembali saat berhenti '
      '(v1.33.1 P7)', (tester) async {
    final db = await _newDb(tester);
    try {
      await _seed(tester, db);
      await tester.pumpWidget(_app(db));
      await _pump(tester);
      final slide = find.byKey(const ValueKey('home:fab-slide'));
      double dy() => tester.widget<AnimatedSlide>(slide).offset.dy;
      expect(dy(), 0);

      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(scrollable.first),
      );
      await gesture.moveBy(const Offset(0, -140));
      await tester.pump(const Duration(milliseconds: 50));
      expect(dy(), greaterThan(0), reason: 'harus tuck saat scroll turun');

      await gesture.up();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(dy(), 0, reason: 'harus kembali setelah scroll berhenti');
    } finally {
      await _cleanup(tester, db);
    }
  });
}
