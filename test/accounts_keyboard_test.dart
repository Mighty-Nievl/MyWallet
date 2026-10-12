// Regression: sheet dompet keyboard-safe (bug laporan 12 Okt 2026 —
// input "Dompet baru" hilang saat keyboard naik).
//
// Akar masalah: showModalBottomSheet standar (tanpa isScrollControlled)
// dibatasi max 50% layar + tak ada padding viewInsets → saat keyboard
// naik, input terdorong keluar layar. Fix: isScrollControlled + padding
// viewInsets.bottom di 3 sheet (tambah, ganti-nama, transfer).
//
// Test: buka sheet → simulasikan keyboard (viewInsets bawah 400px) →
// TextField harus tetap di atas keyboard.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';

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

Future<void> _pump(WidgetTester tester, {int ticks = 20}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _cleanup(WidgetTester tester, AppDatabase db) async {
  try {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => db.close());
  } catch (_) {}
}

/// Keyboard naik 400px lalu turun lagi. Return rect TextField saat
/// keyboard terbuka.
Future<Rect> _rectWithKeyboard(
  WidgetTester tester,
  Finder field,
) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 400);
  await _pump(tester, ticks: 10);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 50));
  final rect = tester.getRect(field);
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pump(const Duration(milliseconds: 50));
  return rect;
}

void main() {
  testWidgets('sheet Dompet baru: input tetap di atas keyboard (v1.25.1)',
      (tester) async {
    final db = await _newDb(tester);
    try {
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

      await tester.tap(find.text('Tambah dompet'));
      await _pump(tester);
      final field = find.byType(TextField);
      expect(field, findsOneWidget);

      final rect = await _rectWithKeyboard(tester, field);
      // Layar 844 - keyboard 400 = batas atas keyboard di y=444.
      // Input harus seluruhnya di atasnya.
      expect(
        rect.bottom,
        lessThanOrEqualTo(444),
        reason: 'input terdorong keluar layar saat keyboard naik',
      );
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('sheet Pindah dana: input nominal di atas keyboard (v1.25.1)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.runAsync(() async {
        await db.into(db.accounts).insert(
              AccountsCompanion.insert(name: 'Keluarga'),
            );
      });
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
      final field = find.byType(TextField);
      expect(field, findsWidgets);

      final rect = await _rectWithKeyboard(tester, field.first);
      expect(
        rect.bottom,
        lessThanOrEqualTo(444),
        reason: 'input nominal terdorong keluar layar saat keyboard naik',
      );
    } finally {
      await _cleanup(tester, db);
    }
  });
}
