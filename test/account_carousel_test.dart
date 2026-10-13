// Regresi carousel kartu dompet Beranda (v1.29): PageView per-dompet
// gantikan hero gabungan + strip chip. Pump manual + flush Drift
// (tanpa pumpAndSettle) ikut pola home_design_test.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';
import 'package:mywallet/ui/screens/account_detail_screen.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
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
    // v1.30: dots = halaman (1 dompet + Kelola = 2 dots).
    expect(find.byKey(const ValueKey('home:dots-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home:dots-manage')), findsOneWidget);
    // Kartu Kelola trailing (v1.29.1) belum di-build — di luar viewport.
    expect(find.byKey(const ValueKey('home:card-manage')), findsNothing);
    // Chip Semua (era chip) sudah tidak ada.
    expect(find.text('Semua'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Kartu Kelola (v1.29.1): halaman TERAKHIR carousel, bergambar gear,
  // tap → Kelola. v1.30: dots = indikator halaman (Kelola dapat 1 dot).
  testWidgets('kartu Kelola trailing: geser → tap → Kelola (v1.29.1)',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    // 1 dompet = 2 halaman (Utama + Kelola). Geser 1x → kartu Kelola.
    // v1.32: fling -200/1000 (drag presisi tanpa velocity tak lewati
    // snap sejak kartu ramping 188px — terbukti probe: drag -200 snap
    // balik, fling pindah 1 halaman).
    await tester.fling(
      find.byKey(const ValueKey('home:carousel')),
      const Offset(-200, 0),
      1000,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('home:card-manage')), findsOneWidget);
    expect(find.text('Kelola dompet'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    // Dot Kelola ikut menyala (halaman trailing tampil).
    expect(find.byKey(const ValueKey('home:dots-manage')), findsOneWidget);
    // Filter tak berubah di halaman trailing (masih Utama).
    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;
    final ctx = tester.element(find.byKey(const ValueKey('home:carousel')));
    expect(
      ProviderScope.containerOf(ctx).read(selectedAccountProvider),
      utamaId,
    );
    // Tap kartu → layar Kelola terbuka.
    await tester.tap(find.text('Kelola dompet'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AccountsScreen), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // Dots Kelola (v1.30): tap dot trailing → lompat ke kartu Kelola,
  // filter TIDAK berubah (guard onPageChanged).
  testWidgets('tap dots-manage → halaman Kelola, filter tetap (v1.30)',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;

    await tester.tap(find.byKey(const ValueKey('home:dots-manage')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('home:card-manage')), findsOneWidget);
    final ctx = tester.element(find.byKey(const ValueKey('home:carousel')));
    expect(
      ProviderScope.containerOf(ctx).read(selectedAccountProvider),
      utamaId,
    );

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
    // v1.30: halaman trailing Kelola ikut dapat dot.
    expect(find.byKey(const ValueKey('home:dots-manage')), findsOneWidget);
    // Halaman 0 = Utama. Geser kiri → halaman 1 = Keluarga.
    // (PageView drop halaman offstage dari cache — setelah geser,
    // Utama hilang total dan Keluarga tepat 1, bukan findsWidgets.)
    // v1.32: fling -200/1000 = 1 halaman (drag presisi snap-balik sejak
    // kartu 188px; terbukti probe).
    await tester.fling(
      find.byKey(const ValueKey('home:carousel')),
      const Offset(-200, 0),
      1000,
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

  // v1.32: CTA kartu DIHAPUS — tap kartu = detail dompet
  // (AccountDetailScreen). Tanpa reorder, sortOrder sama → urut nama
  // (Keluarga dulu, terbukti probe) — jadi reorder [Utama, Keluarga]
  // dulu agar kartu tampil = Utama. Gotcha route-stack (v1.27): judul
  // detail vs nama kartu di bawah → assert via key hero.
  testWidgets('tap kartu buka detail dompet (v1.32)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(
        db.accounts,
      ).get()).firstWhere((a) => a.name == 'Utama');
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await reorderAccounts(db, [utama.id, keluargaId]);
    });
    await _pumpCarousel(tester, db);

    // Kartu pertama (Utama) tampil penuh — tap kartunya.
    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;
    await tester.tap(find.byKey(ValueKey('home:card-$utamaId')));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Layar detail terbuka (hero + seksi recent scoped).
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(find.byKey(ValueKey('detail:hero-$utamaId')), findsOneWidget);

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

  // Task 6 (integrasi, HomeScreen penuh):
  // geser kartu → top kategori ikut filter dompet tampil.
  testWidgets('integrasi: geser → top kategori ikut dompet (v1.29)',
      (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final bulanIni = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(
        db.accounts,
      ).get()).firstWhere((a) => a.name == 'Utama');
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await reorderAccounts(db, [utama.id, keluargaId]);
      Future<void> tx(
        int amount,
        int cat,
        int accountId,
        String note,
      ) => db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: amount,
              isExpense: const Value(true),
              categoryId: Value(cat),
              date: bulanIni,
              note: Value(note),
              accountId: Value(accountId),
            ),
          );
      await tx(45000, 1, utama.id, 'JajanUtama');
      await tx(18000, 2, keluargaId, 'OjekKeluarga');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(onGoTab: (_) {}),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Kartu 0 = Utama → kategorinya tampil, Keluarga belum.
    // (Top kategori ikut selectedAccountProvider; riwayat tidak —
    // riwayat pakai watchHistory tanpa filter akun, kontrak lama.)
    expect(find.byKey(const ValueKey('home:carousel')), findsOneWidget);

    // Geser ke Keluarga → selected berubah → kategori ikut.
    // v1.32: fling -350/1000 (drag presisi snap-balik sejak kartu 188px;
    // -350 di HomeScreen penuh agar lewati threshold; fling -200/1000 =
    // 1 halaman, terbukti probe — tak lompat ke Kelola).
    await tester.fling(
      find.byKey(const ValueKey('home:carousel')),
      const Offset(-350, 0),
      1000,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Keluarga'), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // Task 6 (integrasi): CTA kartu kedua → tx tersimpan di dompet kedua.
  testWidgets('integrasi: CTA kartu kedua → tx dompet kedua (v1.29)',
      (tester) async {
    final db = await _newDb(tester);
    try {
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(
        db.accounts,
      ).get()).firstWhere((a) => a.name == 'Utama');
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await reorderAccounts(db, [utama.id, keluargaId]);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(onGoTab: (_) {}),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // v1.32: CTA kartu DIHAPUS — pintu catat scoped = grid 'Catat
    // keluar' (ikut filter Keluarga) + form tampilkan 'Catat ke'.
    // (fling -350/1000: lewati threshold snap HomeScreen penuh; fling
    // -200/1000 = 1 halaman, terbukti probe — tak lompat ke Kelola.)
    await tester.fling(
      find.byKey(const ValueKey('home:carousel')),
      const Offset(-350, 0),
      1000,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Keluarga'), findsOneWidget);
    // Grid Beranda → Catat keluar (filter = Keluarga).
    await tester.tap(find.text('Catat keluar'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(TxFormScreen), findsOneWidget);
    // Form TERLIHAT catat ke dompet mana (v1.32, request user).
    expect(find.text('Catat ke'), findsOneWidget);
    expect(find.text('Keluarga'), findsWidgets);
    // Isi nominal + simpan (kategori default pertama).
    await tester.enterText(
      find.byType(TextField).first,
      '25000',
    );
    await tester.pump(const Duration(milliseconds: 200));
    // Ekor form malas: tombol Simpan anak TERAKHIR ListView form
    // (tx_form_screen.dart). Di font CI (DejaVu, lebih tinggi dari
    // Segoe) ia belum di-build → finder nol. Gulir-cari sampai ketemu
    // (maks 10 ayunan), baru tap. Terbukti via probe viewport-pendek.
    final formList = find.descendant(
      of: find.byType(TxFormScreen),
      matching: find.byType(ListView),
    );
    final saveBtn = find.text('Simpan Transaksi');
    for (var i = 0; i < 10; i++) {
      if (saveBtn.evaluate().isNotEmpty) break;
      await tester.fling(formList, const Offset(0, -500), 1000);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.ensureVisible(saveBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(saveBtn);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Tx tersimpan di dompet Keluarga (bukan Utama).
    final txs = (await tester.runAsync(
      () => db.select(db.transactions).get(),
    ))!;
    expect(txs, isNotEmpty);
    final keluarga = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Keluarga');
    expect(
      txs.any((t) => t.accountId == keluarga.id && t.amount == 25000),
      isTrue,
    );
    } finally {
      await _flushDriftCloseTimer(tester);
    }
  });
}
