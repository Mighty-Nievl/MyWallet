// Regression v1.36.2: dompet arsip bisa dipulihkan dari layar Dompet.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';
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

Future<void> _pump(WidgetTester tester, {int ticks = 60}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _flushDriftCloseTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
}

void main() {
  testWidgets('dompet arsip bisa dipulihkan (v1.36.2)', (tester) async {
    final db = await _newDb(tester);
    final utamaId = (await tester.runAsync(() async {
      final utama = (await db.select(db.accounts).get()).single;
      await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await archiveAccount(db, utama.id);
      return utama.id;
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountsScreen(),
        ),
      ),
    );
    await _pump(tester);
    final open = find.text('Dompet diarsipkan (1)');
    await _waitFor(tester, open);
    expect(open, findsOneWidget, reason: 'pintu pemulihan arsip hilang');

    await tester.tap(open);
    await _pump(tester);
    await _waitFor(tester, find.text('Pulihkan'));
    await tester.tap(find.byKey(ValueKey('restore-$utamaId')));
    await _pump(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await _pump(tester);

    final row = await tester.runAsync(
      () => (db.select(
        db.accounts,
      )..where((a) => a.id.equals(utamaId))).getSingle(),
    );
    expect(row!.isArchived, isFalse);
    await _flushDriftCloseTimer(tester);
  });
}
