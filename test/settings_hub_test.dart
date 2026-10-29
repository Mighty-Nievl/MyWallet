// Hub Pengaturan — pencarian harus menemukan SEMUA baris, termasuk yang
// dulu tidak ada di daftar hardcoded.
//
// Regresi yang dikunci: v1.42.0 mencari "pdf"/"backup otomatis" dari hub
// tidak menemukan apa pun karena `_HubEntry` hanya punya 25 entri untuk 32
// baris nyata. Sekarang hub membaca `SettingsCatalog.all`.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/settings_screen.dart';

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
  testWidgets('hub: 7 setelan yang dulu hilang kini ketemu', (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Tanpa pencarian: 4 grup.
      expect(find.text('Tampilan'), findsOneWidget);
      expect(find.text('Kelola'), findsOneWidget);

      Future<void> cari(String q, String harapan) async {
        await tester.enterText(find.byType(TextField), q);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.text(harapan),
          findsOneWidget,
          reason: 'query "$q" harus menemukan "$harapan"',
        );
      }

      await cari('pdf', 'Export PDF laporan');
      await cari('backup otomatis', 'Backup otomatis');
      await cari('backup terakhir', 'Backup terakhir');
      await cari('pulihkan', 'Pulihkan backup otomatis');
      await cari('jam', 'Jam pengingat');
      await cari('nama', 'Nama sapaan');
      await cari('jumlah', 'Jumlah ditampilkan');

      // Query ngawur: pesan kosong, bukan halaman bingung.
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Tidak ada pengaturan yang cocok.'), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });
}
