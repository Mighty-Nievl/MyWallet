// Kontrak UI Pengaturan (v1.45) — hasil audit `ui-ux-pro-max`
// (`references/pro-rules.md`), diukur dari rect, bukan selera.
//
// Yang dikunci:
// - target sentuh ≥48 (baris 70, switch 60×48, kotak cari 48)
// - label grup di rail halaman x=16 (dulu x=20 karena `left: 4`)
// - divider mulai di kolom teks (indent 64 = 12 + 40 + 12), bukan 52
// - ekor list 32 (dulu 96 — halaman pengaturan tidak punya FAB)
// - empty state pencarian punya saran + jalan keluar, bukan buntu
// - teks 2× (Dynamic Type) tidak overflow di 375 & 320
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/components/setting_row.dart';
import 'package:mywallet/ui/design/app_spacing.dart';
import 'package:mywallet/ui/screens/settings_appearance.dart';
import 'package:mywallet/ui/screens/settings_screen.dart';

Future<AppDatabase> _db(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final db = await t.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.customSelect('SELECT 1').get();
    await d.backfillAccounts();
    return d;
  });
  return db!;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  AppDatabase db, {
  double width = 375,
  double scale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 812);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  for (var i = 0; i < 16; i++) {
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

void main() {
  testWidgets('target sentuh + rail + divider + ekor list', (tester) async {
    final db = await _db(tester);
    try {
      await _pump(tester, const AppearanceSettingsPage(), db);

      // Target sentuh: baris 70 (>48), switch 60×48.
      expect(
        tester.getSize(find.byType(SettingRow).first).height,
        greaterThanOrEqualTo(48),
        reason: 'baris pengaturan harus ≥48dp (Android)',
      );
      final sw = tester.getSize(find.byType(Switch).first);
      expect(sw.height, greaterThanOrEqualTo(48));
      expect(sw.width, greaterThanOrEqualTo(48));

      // Kotak cari 48.
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(48),
      );

      // Label grup di rail halaman (x=16), bukan x=20.
      expect(tester.getRect(find.text('Warna & tema')).left, AppSpacing.page);

      // Divider mulai di kolom teks.
      final divider = tester.widget<Divider>(find.byType(Divider).first);
      expect(divider.indent, 64);

      // Ekor list 32, bukan 96 (tidak ada FAB di halaman ini).
      final lv = tester.widget<ListView>(find.byType(ListView));
      final pad = lv.padding as EdgeInsets;
      expect(pad.bottom, AppSpacing.sectionGapLarge);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('empty state pencarian: ada saran + tombol bersihkan', (
    tester,
  ) async {
    final db = await _db(tester);
    try {
      await _pump(tester, const SettingsScreen(), db);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Tidak ada pengaturan yang cocok.'), findsOneWidget);
      expect(find.textContaining('Coba kata lain'), findsOneWidget);
      expect(find.text('Bersihkan pencarian'), findsOneWidget);

      // Tombol ikon clear punya nama aksesibel.
      await tester.enterText(find.byType(TextField), 'tema');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byTooltip('Bersihkan pencarian'), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('Dynamic Type 2× tidak overflow (375 & 320)', (tester) async {
    final db = await _db(tester);
    try {
      await _pump(tester, const AppearanceSettingsPage(), db, scale: 2.0);
      expect(tester.takeException(), isNull, reason: 'overflow di 375/2×');

      await _pump(
        tester,
        const AppearanceSettingsPage(),
        db,
        width: 320,
        scale: 2.0,
      );
      expect(tester.takeException(), isNull, reason: 'overflow di 320/2×');
    } finally {
      await _cleanup(tester, db);
    }
  });
}
