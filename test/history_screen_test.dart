import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget test Riwayat (v1.24.8) — nutup kritik brutal L1/L3/L4.
///
/// - Chip "Semua" beneran semua (reset kategori juga, bukan cuma tipe).
/// - Strip hasil: count + masuk + keluar hasil filter aktif.
/// - Grup tanggal ala Beranda (header grup + showDate false).
///
/// Harness ikut pola debt_widget_test: pump manual + _waitFor +
/// try/finally, tanpa pumpAndSettle.
Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<bool> _waitFor(WidgetTester tester, Finder f,
    {int rounds = 40}) async {
  for (var i = 0; i < rounds; i++) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return true;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.pump(const Duration(milliseconds: 50));
  return f.evaluate().isNotEmpty;
}

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.customSelect('SELECT 1').get();
    return d;
  });
  addTearDown(db!.close);
  return db;
}

Future<void> _tx(
  AppDatabase db,
  int amount,
  bool isExpense,
  int cat,
  DateTime date, {
  String note = '',
}) =>
    db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            isExpense: Value(isExpense),
            categoryId: Value(cat),
            date: date,
            note: Value(note),
          ),
        );

Future<void> _pumpHistory(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const HistoryScreen(),
      ),
    ),
  );
  await _pump(tester, ticks: 10);
}

Future<void> _flushDb(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('chip Semua reset kategori juga (v1.24.8)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);

      // Aktifkan filter kategori: scroll ke chip lalu ketuk
      // (chip kategori off-screen di horizontal scroll).
      final chip = find.textContaining('Makan & Minum').first;
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await _pump(tester);
      // Ojek (Transportasi) ikut hilang karena filter kategori.
      expect(find.text('Ojek'), findsNothing);

      // Ketuk "Semua" → kategori ikut reset, Ojek muncul lagi.
      final semua = find.text('Semua');
      await tester.ensureVisible(semua);
      await tester.pump();
      await tester.tap(semua);
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Ojek')), isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('strip hasil: count + masuk + keluar (v1.24.8)',
      (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 100000, false, 9, today, note: 'Gaji');
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(
          await _waitFor(tester, find.textContaining('3 transaksi')),
          isTrue);
      expect(find.textContaining('Masuk +Rp100.000'), findsOneWidget);
      expect(find.textContaining('Keluar -Rp63.000'), findsOneWidget);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('grup tanggal: header grup + tanpa tanggal per baris (v1.24.8)',
      (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 60000, true, 1, yesterday, note: 'Seblak');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Hari ini')), isTrue);
      expect(find.text('Kemarin'), findsOneWidget);
      // Tanggal tidak diulang di subtitle tiap baris.
      expect(find.textContaining('· Hari ini'), findsNothing);
      expect(find.textContaining('· Kemarin'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });
}
