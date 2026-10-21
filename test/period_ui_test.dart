// Test v1.35.0 — periode analitik (harian/mingguan/bulanan/tahunan).
//
// Dua lapis:
// 1. Provider: rentang periode benar-benar mengubah hasil query (bukan
//    sekadar label) — dibuktikan dengan dua transaksi di tanggal berbeda.
// 2. Widget Laporan: chip switcher mengubah periode aktif, judul seksi
//    ikut, dan chevron menggeser satu unit periode.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/period.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/format.dart';
import 'package:mywallet/ui/screens/reports_screen.dart';

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = (await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.backfillAccounts();
    return d;
  }))!;
  addTearDown(db.close);
  return db;
}

Future<void> _seed(
  AppDatabase db, {
  required DateTime when,
  required int amount,
}) async {
  final utama = (await db.select(db.accounts).get())
      .firstWhere((a) => a.name == 'Utama')
      .id;
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: const Value(true),
          categoryId: const Value(1),
          date: when,
          accountId: Value(utama),
        ),
      );
}

Future<void> _pumpReports(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const ReportsScreen()),
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('rentang periode mengubah hasil query, bukan cuma label', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final tenDaysAgo = DateTime(now.year, now.month, now.day - 10, 12);

    await tester.runAsync(() async {
      // Dua pengeluaran: hari ini 50.000, sepuluh hari lalu 30.000.
      await _seed(db, when: today, amount: 50000);
      await _seed(db, when: tenDaysAgo, amount: 30000);
    });

    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Bulanan: kedua transaksi masuk (asalkan keduanya di bulan berjalan;
    // test ini memakai bulan berjalan, jadi 10 hari lalu masih di bulan
    // yang sama kecuali hari ini < tanggal 11 — maka ekspektasinya
    // dihitung dari rentang, bukan diasumsikan 80.000).
    final monthRange = Period.of(PeriodKind.bulanan, today).range;
    final expectMonth = (tenDaysAgo.isBefore(monthRange.$1) ? 0 : 30000) + 50000;
    final monthly = await tester.runAsync(
      () => container.read(periodTotalsProvider.future),
    );
    expect(monthly!.$2, expectMonth);

    // Harian: hanya transaksi hari ini.
    container.read(periodKindProvider.notifier).state = PeriodKind.harian;
    container.read(periodAnchorProvider.notifier).state = today;
    final daily = await tester.runAsync(
      () => container.read(periodTotalsProvider.future),
    );
    expect(daily!.$2, 50000, reason: 'harian hanya menjumlah hari ini');

    // Mingguan: hari ini pasti masuk; 10 hari lalu pasti TIDAK (di luar 7 hari).
    container.read(periodKindProvider.notifier).state = PeriodKind.mingguan;
    final weekly = await tester.runAsync(
      () => container.read(periodTotalsProvider.future),
    );
    expect(weekly!.$2, 50000, reason: 'mingguan tak menarik transaksi 10 hari lalu');
  });

  testWidgets('chip Mingguan mengubah periode aktif + judul seksi', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await _pumpReports(tester, db);

    final today = DateTime.now();
    final monthlyLabel = monthLabel(monthKey(today));
    expect(find.text('Ringkasan $monthlyLabel'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('period:kind:mingguan')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final week = Period.of(PeriodKind.mingguan, today);
    expect(find.text('Ringkasan ${periodLabel(week)}'), findsOneWidget);
    // Judul lama tidak boleh tertinggal (dua konteks di satu layar = bohong).
    expect(find.text('Ringkasan $monthlyLabel'), findsNothing);
  });

  testWidgets('chevron menggeser satu unit periode (harian → kemarin)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await _pumpReports(tester, db);

    await tester.tap(find.byKey(const ValueKey('period:kind:harian')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final now = DateTime.now();
    final todayP = Period.of(
      PeriodKind.harian,
      DateTime(now.year, now.month, now.day),
    );
    expect(find.text('Ringkasan ${periodLabel(todayP)}'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('period:prev')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.text('Ringkasan ${periodLabel(todayP.previous)}'),
      findsOneWidget,
    );
  });

  testWidgets('bulanan ⇄ mingguan: bulan tidak ikut berubah', (tester) async {
    final db = await _newDb(tester);
    await _pumpReports(tester, db);

    final before = monthKey(DateTime.now());
    await tester.tap(find.byKey(const ValueKey('period:kind:mingguan')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('period:kind:bulanan')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Kembali ke bulanan = kembali ke bulan yang sama, bukan bulan lain.
    expect(
      find.text('Ringkasan ${monthLabel(before)}'),
      findsOneWidget,
    );
  });
}
