// Regresi carousel kartu dompet Beranda (v1.29): PageView per-dompet
// gantikan hero gabungan + strip chip. Pump manual + flush Drift
// (tanpa pumpAndSettle) ikut pola home_design_test.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/tx_form_screen.dart';
import 'package:mywallet/ui/widgets/account_carousel.dart';
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

Future<void> _pumpCarousel(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AccountCarousel()),
      ),
    ),
  );
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('1 dompet: 1 kartu, dots sembunyi (v1.29)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    expect(find.text('Utama'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:carousel')), findsOneWidget);
    expect(find.byKey(const ValueKey('home:dots-0')), findsNothing);
    expect(find.text('Kelola dompet'), findsOneWidget);
    // Chip Semua (era chip) sudah tidak ada.
    expect(find.text('Semua'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  testWidgets('2 dompet: geser ganti halaman + dots tampil (v1.29)',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(
        db.accounts,
      ).get()).firstWhere((a) => a.name == 'Utama');
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      // Urutan eksplisit [Utama, Keluarga]: tanpa reorder, sortOrder
      // sama-sama 0 → urut nama (Keluarga dulu). Probe buktikan fling
      // jalan (SELECTED berubah) — yang salah asumsi urutan test ini.
      await reorderAccounts(db, [utama.id, keluargaId]);
    });
    await _pumpCarousel(tester, db);

    expect(find.byKey(const ValueKey('home:dots-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home:dots-1')), findsOneWidget);
    // Halaman 0 = Utama. Geser kiri → halaman 1 = Keluarga.
    // (PageView drop halaman offstage dari cache — setelah geser,
    // Utama hilang total dan Keluarga tepat 1, bukan findsWidgets.)
    await tester.fling(
      find.byKey(const ValueKey('home:carousel')),
      const Offset(-400, 0),
      800,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Kartu kedua tampil penuh (nama Keluarga terlihat di viewport).
    final fam = find.text('Keluarga');
    expect(fam, findsOneWidget);
    expect(tester.getCenter(fam).dx, greaterThan(0));

    await _flushDriftCloseTimer(tester);
  });

  testWidgets('CTA kartu buka form catat (v1.29)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Keluarga'));
    });
    await _pumpCarousel(tester, db);

    // Kartu pertama (Utama) tampil penuh — tap CTA-nya.
    await tester.tap(find.widgetWithText(FilledButton, '+ Catat keluar').first);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Form catat terbuka.
    expect(find.byType(TxFormScreen), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  testWidgets('kosong (semua arsip): empty-state (v1.29)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(
        db.accounts,
      ).get()).firstWhere((a) => a.name == 'Utama');
      await archiveAccount(db, utama.id);
    });
    await _pumpCarousel(tester, db);

    expect(find.text('Belum ada dompet'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:carousel')), findsNothing);

    await _flushDriftCloseTimer(tester);
  });
}
