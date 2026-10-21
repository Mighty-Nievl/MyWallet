// Regression v1.36.2: kaki transfer TIDAK boleh dibuka di form transaksi
// biasa (edit satu sisi merusak pasangan saldo). Tap Riwayat harus membuka
// aksi transfer + hapus berpasangan.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  addTearDown(db!.close);
  return db;
}

Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int rounds = 40,
}) async {
  for (var i = 0; i < rounds; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
}

void main() {
  testWidgets('tap transfer membuka aksi berpasangan, bukan form transaksi', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final ids = (await tester.runAsync(() async {
      final utama = (await db.select(db.accounts).get()).single;
      final keluarga = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await insertTransfer(
        db,
        fromAccountId: utama.id,
        toAccountId: keluarga,
        amount: 75000,
        date: DateTime.now(),
        note: 'pindah',
      );
      return (utama: utama.id, keluarga: keluarga);
    }))!;

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
    final row = find.textContaining('Transfer · pindah').first;
    await _waitFor(tester, row);
    expect(row, findsOneWidget);

    await tester.tap(row);
    await _pump(tester);
    expect(find.text('Transfer antar dompet'), findsOneWidget);
    // Form transaksi punya kolom nominal/catatan + tombol Simpan.
    expect(find.text('Simpan'), findsNothing);

    await tester.tap(find.text('Hapus transfer'));
    await _pump(tester);
    expect(find.text('Hapus transfer?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await _pump(tester, ticks: 20);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await _pump(tester);

    final left = await tester.runAsync(
      () =>
          (db.select(db.transactions)..where(
                (t) =>
                    t.accountId.equals(ids.utama) |
                    t.accountId.equals(ids.keluarga),
              ))
              .get(),
    );
    expect(left, hasLength(2));
    expect(left!.every((t) => t.deletedAt != null), isTrue);
    expect(find.text('Transfer antar dompet'), findsNothing);
  });
}
