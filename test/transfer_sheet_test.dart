// Regression v1.36.2: sheet pindah dana punya tanggal yang ikut periode
// aktif (dulu diam-diam selalu DateTime.now()).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await d.into(d.accounts).insert(AccountsCompanion.insert(name: 'Keluarga'));
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

void main() {
  testWidgets('sheet pindah dana menampilkan tanggal (v1.36.2)', (
    tester,
  ) async {
    final db = await _newDb(tester);
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

    await tester.tap(find.byTooltip('Pindah dana').first);
    await _pump(tester);

    expect(find.text('Pindah dana'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transfer-date')),
      findsOneWidget,
      reason: 'tanggal transfer tak terlihat — user tak bisa tahu masuk periode mana',
    );
  });
}
