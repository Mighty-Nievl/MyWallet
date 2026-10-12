// Regression test Laporan (v1.24.11, audit brutal L1/L3/L4/L5).
//
// Tanpa pumpAndSettle (aturan anti-flaky): pump manual + _waitFor.
// Fungsi murni (fetchSixMonthFlow, insightText, pieSliceLabel)
// di-test langsung tanpa UI; sisanya widget-test dengan DB memory
// (kategori default ter-seed otomatis oleh AppDatabase).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/settings.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Tunggu finder muncul (StreamProvider async). false = menyerah.
Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int ticks = 40,
}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = (await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.backfillAccounts(); // seed Utama (v1.25)
    return d;
  }))!;
  addTearDown(db.close);
  return db;
}

/// Id dompet Utama (di-seed _newDb) — v1.25: helper tx WAJIB isi ini.
Future<int> _utama(AppDatabase db) async => (await db.select(db.accounts).get())
    .firstWhere((a) => a.name == 'Utama')
    .id;

Future<void> _tx(
  AppDatabase db,
  int amount,
  bool isExpense,
  int cat,
  DateTime date, {
  String note = '',
}) async {
  final utama = await _utama(db);
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: Value(isExpense),
          categoryId: Value(cat),
          date: date,
          note: Value(note),
          accountId: Value(utama),
        ),
      );
}

Future<void> _pumpReports(
  WidgetTester tester,
  AppDatabase db, {
  bool privacyAll = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        // Mode privacy penuh (hide + scope all) — tanpa tipe Override
        // eksplisit (Riverpod 3.x tak ekspor nama itu di sini).
        if (privacyAll) ...[
          hideBalanceProvider.overrideWith((ref) async => true),
          privacyScopeProvider.overrideWith((ref) async => 'all'),
        ],
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ReportsScreen()),
    ),
  );
  await _pump(tester);
}

void main() {
  // L1 (guard future): 6 titik, ascending, jangkar = bulan yang
  // dilihat (BUKAN bulan HP) — DateTime.now dilarang di sini.
  test('fetchSixMonthFlow: 6 titik jangkar bulan lihat', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.backfillAccounts(); // seed Utama (v1.25)
    await _tx(db, 1000000, false, 9, DateTime(2026, 1, 5, 8));
    await _tx(db, 200000, true, 1, DateTime(2026, 1, 6, 12));
    final rows = await fetchSixMonthFlow(db, '2026-03');
    expect(rows.length, 6);
    expect(rows.last.key, '2026-03');
    expect(rows.first.key, '2025-10');
    final jan = rows.firstWhere((r) => r.key == '2026-01');
    expect(jan.masuk, 1000000);
    expect(jan.keluar, 200000);
    final mar = rows.last;
    expect(mar.masuk, 0);
    expect(mar.keluar, 0);
  });

  // L5 (insight jujur): 5 kasus — naik, turun, sama, mulai-ada,
  // nol-nol (null). prev 0 + ada nilai = kalimat, BUKAN "∞%".
  test('insightText: 5 kasus jujur', () {
    String m(int v) => 'Rp$v';
    expect(
      insightText(keluar: 200, prevKeluar: 100, prevLabel: 'Sep', money: m),
      contains('naik 100%'),
    );
    expect(
      insightText(keluar: 50, prevKeluar: 100, prevLabel: 'Sep', money: m),
      contains('turun 50%'),
    );
    expect(
      insightText(keluar: 100, prevKeluar: 100, prevLabel: 'Sep', money: m),
      contains('sama dengan Sep'),
    );
    final fresh = insightText(
      keluar: 75,
      prevKeluar: 0,
      prevLabel: 'Sep',
      money: m,
    )!;
    expect(fresh, contains('Mulai ada'));
    expect(fresh, isNot(contains('%')));
    expect(
      insightText(keluar: 0, prevKeluar: 0, prevLabel: 'Sep', money: m),
      isNull,
    );
  });

  // L4 (iris kecil): <=3% tanpa label, besar tetap berlabel.
  test('pieSliceLabel: iris kecil bisu, besar bicara', () {
    expect(pieSliceLabel(2, 100), '');
    expect(pieSliceLabel(3, 100), '');
    expect(pieSliceLabel(4, 100), '4%');
    expect(pieSliceLabel(41, 100), '41%');
    expect(pieSliceLabel(10, 0), '');
  });

  // L4 (judul jujur): ikut bulan yang dilihat, bukan "bulan ini".
  testWidgets('judul seksi dinamis ikut bulan', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    await _tx(db, 100000, true, 1, DateTime(now.year, now.month, 5, 12));
    try {
      await _pumpReports(tester, db);
      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      // Static label lama wajib HILANG (klaim "ini" saat lihat
      // bulan lain = breach L4).
      expect(find.text('Ringkasan bulan ini'), findsNothing);
      expect(find.text('Rincian bulan ini'), findsNothing);
      // Test hanya tahu bulan berjalan (selectedMonth default).
      expect(key, currentMonthKeyForTest(now));
      expect(find.textContaining('Ringkasan '), findsOneWidget);
      expect(find.textContaining('Rincian '), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  // L4 (legenda) + L1 (semantik chart): Masuk/Keluar terlihat,
  // screen reader dengar ringkas tiap bulan.
  testWidgets('legenda + semantik grafik', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    await _tx(db, 5000000, false, 9, DateTime(now.year, now.month, 2, 8));
    await _tx(db, 150000, true, 1, DateTime(now.year, now.month, 5, 12));
    try {
      await _pumpReports(tester, db);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Grafik arus 6 bulan')),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  // L4 (privacy): mode sembunyi → semantik grafik ikut Rp••••
  // (bocor visual tertutup — batang rata + label tersamar).
  testWidgets('privacy: semantik grafik tersamar', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    await _tx(db, 5000000, false, 9, DateTime(now.year, now.month, 2, 8));
    try {
      await _pumpReports(tester, db, privacyAll: true);
      expect(await _waitFor(tester, find.text('Masuk')), isTrue);
      // Semantik tersamar ADA (chart label + node internal fl_chart
      // → findsWidgets, bukan One), dan nominal mentah TAK ADA
      // di widget teks manapun (bocor visual tertutup).
      expect(find.bySemanticsLabel(RegExp(r'Rp••••')), findsWidgets);
      expect(find.textContaining('5.000.000'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  // L5 (strip jawaban): keluar naik vs bulan lalu → strip tampil.
  testWidgets('strip wawasan: naik vs bulan lalu', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    await _tx(db, 200000, true, 1, DateTime(now.year, now.month, 5, 12));
    await _tx(db, 100000, true, 1, DateTime(now.year, now.month - 1, 5, 12));
    try {
      await _pumpReports(tester, db);
      expect(await _waitFor(tester, find.text('Masuk')), isTrue);
      expect(find.textContaining('naik 100%'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  // L4 (footnote): 7 kategori → klaim 6-terbesar eksplisit.
  testWidgets('footnote 6-terbesar saat kategori > 6', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    for (var c = 1; c <= 7; c++) {
      await _tx(db, c * 10000, true, c, DateTime(now.year, now.month, 5, c));
    }
    try {
      await _pumpReports(tester, db);
      expect(
        await _waitFor(
          tester,
          find.text('Menampilkan 6 terbesar dari 7 kategori.'),
        ),
        isTrue,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

/// Kunci bulan "yyyy-MM" dari tanggal — cermin monthKey() tanpa
/// import format (test tetap ringan + eksplisit).
String currentMonthKeyForTest(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';
