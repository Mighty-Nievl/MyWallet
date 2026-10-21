// Test v1.36.0 — kalender grid + total harian.
//
// Kontrak:
// - Query [AppDatabase.getDailyTotals] mengelompokkan per hari LOKAL dan
//   tidak menghitung kaki transfer.
// - Layar kalender menampilkan total ringkas per tanggal (privacy dihormati).
// - Ketuk tanggal → periode aktif jadi Harian di tanggal itu + layar tutup.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/period.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/settings.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/calendar_screen.dart';

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

Future<int> _utama(AppDatabase db) async {
  final accounts = await db.select(db.accounts).get();
  return accounts.firstWhere((a) => a.name == 'Utama').id;
}

Future<void> _seed(
  AppDatabase db, {
  required DateTime when,
  required int amount,
  required bool isExpense,
  String? transferId,
}) async {
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: Value(isExpense),
          categoryId: Value(1),
          date: when,
          accountId: Value(await _utama(db)),
          transferId: Value(transferId),
        ),
      );
}

Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('getDailyTotals mengelompokkan per hari & buang transfer', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 12);

    await tester.runAsync(() async {
      await _seed(db, when: today, amount: 50000, isExpense: true);
      await _seed(db, when: today, amount: 20000, isExpense: false);
      await _seed(db, when: yesterday, amount: 30000, isExpense: true);
      // Kaki transfer: tidak boleh masuk pemasukan/pengeluaran.
      await _seed(
        db,
        when: today,
        amount: 999000,
        isExpense: true,
        transferId: 't-1',
      );
    });

    final totals = await tester.runAsync(
      () => db.getDailyTotals(
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
    );
    expect(totals![DateTime(now.year, now.month, now.day)], (20000, 50000));
    expect(totals[DateTime(now.year, now.month, now.day - 1)], (
      0,
      30000,
    ), reason: 'hari kemarin hanya pengeluaran 30.000');
  });

  testWidgets('grid menampilkan total harian + privacy', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    await tester.runAsync(() async {
      await _seed(db, when: today, amount: 50000, isExpense: true);
      await _seed(db, when: today, amount: 20000, isExpense: false);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CalendarScreen(),
        ),
      ),
    );
    await _pump(tester);

    final day = find.byKey(
      ValueKey('calendar:day:${today.year}-${today.month}-${today.day}'),
    );
    expect(day, findsOneWidget, reason: 'sel tanggal hari ini harus ada');
    expect(
      find.descendant(of: day, matching: find.text('Rp50 rb')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: day, matching: find.text('Rp20 rb')),
      findsOneWidget,
    );

    await _cleanup(tester);
  });

  testWidgets('privacy semua nominal menyamarkan sel kalender', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    await tester.runAsync(() async {
      await _seed(db, when: today, amount: 50000, isExpense: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          hideBalanceProvider.overrideWith((ref) async => true),
          privacyScopeProvider.overrideWith((ref) async => 'all'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CalendarScreen(),
        ),
      ),
    );
    await _pump(tester);

    expect(find.text('Rp••••'), findsWidgets);
    expect(find.textContaining('Rp50'), findsNothing);

    await _cleanup(tester);
  });

  testWidgets('ketuk tanggal → mode Harian + layar tutup', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    await tester.runAsync(() async {
      await _seed(db, when: today, amount: 50000, isExpense: true);
    });

    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const _Host()),
      ),
    );
    await _pump(tester);

    await tester.tap(find.text('Buka kalender'));
    await _pump(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);

    await tester.tap(
      find.byKey(
        ValueKey('calendar:day:${today.year}-${today.month}-${today.day}'),
      ),
    );
    await _pump(tester);

    expect(find.byType(CalendarScreen), findsNothing);
    expect(container.read(periodKindProvider), PeriodKind.harian);
    final anchor = container.read(periodAnchorProvider);
    expect(anchor.year, today.year);
    expect(anchor.month, today.month);
    expect(anchor.day, today.day);

    await _cleanup(tester);
  });
}

/// Host dengan tombol push supaya `Navigator.pop` kalender punya tujuan.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          child: const Text('Buka kalender'),
        ),
      ),
    );
  }
}
