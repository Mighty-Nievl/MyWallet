// Reorder dompet di Kelola (v1.29): drag handle → sortOrder tersimpan.
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, String file) async {
    final f = File(file);
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  const win = 'C:\\\\Windows\\\\Fonts';
  await load('Roboto', '$win\\\\segoeui.ttf');
  await load('Roboto', '$win\\\\segoeuib.ttf');
  await load(
    'MaterialIcons',
    'E:\\\\dev\\\\flutter\\\\bin\\\\cache\\\\artifacts\\\\material_fonts'
        '\\\\materialicons-regular.otf',
  );
}

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

Future<void> _flushDriftCloseTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('drag reorder simpan sortOrder (v1.29)', (tester) async {
    final db = await _newDb(tester);
    final ids = (await tester.runAsync(() async {
      await _loadFonts();
      final aId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'A'));
      final bId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'B'));
      return {'A': aId, 'B': bId};
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
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Urutan awal: A, B, Utama (sortOrder 0 semua → nama).
    expect(find.byKey(ValueKey('acct-${ids['A']}')), findsOneWidget);
    // Delayed listener butuh SATU gestur: tekan handle → tahan 600ms →
    // geser tanpa angkat (longPress+drag terpisah gagal: jari terangkat).
    final handle = find.descendant(
      of: find.byKey(ValueKey('acct-${ids['B']}')),
      matching: find.byIcon(Icons.drag_handle),
    );
    expect(handle, findsOneWidget);
    final cardHeight =
        tester.getSize(find.byKey(ValueKey('acct-${ids['B']}'))).height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(0, -cardHeight / 3));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // sortOrder B kini paling kecil (paling atas).
    final rows = (await tester.runAsync(
      () => (db.select(db.accounts)
            ..orderBy([
              (a) => OrderingTerm.asc(a.sortOrder),
              (a) => OrderingTerm.asc(a.name),
            ])).get(),
    ))!;
    expect(rows.map((a) => a.name).toList(), ['B', 'A', 'Utama']);

    await _flushDriftCloseTimer(tester);
  });
}
