// Regresi carousel kartu dompet Beranda (v1.29): PageView per-dompet
// gantikan hero gabungan + strip chip. Pump manual + flush Drift
// (tanpa pumpAndSettle) ikut pola home_design_test.
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/sync_engine.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/design/app_spacing.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';
import 'package:mywallet/ui/screens/account_detail_screen.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
import 'package:mywallet/ui/screens/tx_form_screen.dart';
import 'package:mywallet/ui/shell.dart';
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
  testWidgets('1 dompet: 1 kartu, tanpa dots + tombol Kelola (v1.37)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    expect(find.text('Utama'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:carousel')), findsOneWidget);
    // v1.37: dots hanya muncul saat >1 dompet — 1 dompet tak butuh
    // indikator halaman. Kelola kini tombol aksi, bukan halaman data.
    expect(find.byKey(const ValueKey('home:dots')), findsNothing);
    expect(find.byKey(const ValueKey('home:dots-0')), findsNothing);
    expect(find.byKey(const ValueKey('home:manage')), findsOneWidget);
    expect(find.text('Kelola dompet'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:card-manage')), findsNothing);
    expect(find.text('Semua'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // v1.37: Kelola keluar dari PageView. Tap tombol → AccountsScreen,
  // filter dompet aktif TIDAK berubah (bukan halaman carousel).
  testWidgets('tombol Kelola buka AccountsScreen tanpa ubah filter', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;
    final ctx = tester.element(find.byKey(const ValueKey('home:carousel')));
    expect(
      ProviderScope.containerOf(ctx).read(selectedAccountProvider),
      utamaId,
    );

    await tester.tap(find.byKey(const ValueKey('home:manage')));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(AccountsScreen)),
      ).read(selectedAccountProvider),
      utamaId,
    );

    await _flushDriftCloseTimer(tester);
  });

  testWidgets('2 dompet: geser ganti halaman + dots tampil (v1.29)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(db.accounts).get()).firstWhere(
        (a) => a.name == 'Utama',
      );
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
    // v1.37.1: slot 28×32 (minimum WCAG 2.2 AA = 24×24). 48px terbukti
    // merusak pitch: celah antar dot jadi 42px.
    for (final key in ['home:dots-0', 'home:dots-1']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(24), reason: key);
      expect(size.height, greaterThanOrEqualTo(24), reason: key);
      expect(size.width, lessThan(AppSpacing.touchMin), reason: key);
    }
    // Indikator aktif beda BENTUK (pill 18px), bukan cuma warna.
    expect(
      tester.getSize(find.byKey(const ValueKey('home:dots-0-visual'))).width,
      18,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home:dots-1-visual'))).width,
      6,
    );
    // v1.37.1: Kelola keluar dari baris dot (kiri = posisi, kanan = aksi).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home:dots')),
        matching: find.byKey(const ValueKey('home:manage')),
      ),
      findsNothing,
    );
    // v1.37: Kelola tidak lagi jadi halaman carousel.
    expect(find.byKey(const ValueKey('home:dots-manage')), findsNothing);
    expect(find.byKey(const ValueKey('home:manage')), findsOneWidget);
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

  // v1.37.1: halaman aktif harus terbaca screen reader — sebelumnya dua
  // dot sama-sama "Dompet N dari M" tanpa status, jadi TalkBack tak bisa
  // membedakan mana yang sedang tampil.
  testWidgets('semantik dot: halaman aktif ditandai selected (v1.37.1)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(db.accounts).get()).firstWhere(
        (a) => a.name == 'Utama',
      );
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await reorderAccounts(db, [utama.id, keluargaId]);
    });
    final handle = tester.ensureSemantics();
    await _pumpCarousel(tester, db);

    final aktif = tester
        .getSemantics(find.byKey(const ValueKey('home:dots-0')))
        .getSemanticsData();
    final pasif = tester
        .getSemantics(find.byKey(const ValueKey('home:dots-1')))
        .getSemanticsData();
    expect(aktif.label, contains('Utama'));
    // Flutter 3.32+ : hasFlag deprecated → flagsCollection (Tristate).
    expect(aktif.flagsCollection.isSelected, Tristate.isTrue);
    expect(pasif.label, contains('Keluarga'));
    expect(pasif.flagsCollection.isSelected, Tristate.isFalse);

    handle.dispose();
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
      final utama = (await db.select(db.accounts).get()).firstWhere(
        (a) => a.name == 'Utama',
      );
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

    // v1.32: seksi Pengaturan dompet (ganti nama + saldo awal + toggle
    // keluarga + arsip) — assert SEBELUM tap FAB (setelah tap, layar =
    // form). Lazy ListView: tail BELUM di-build (aturan v1.24.10) →
    // fling dulu paksa build, baru ensureVisible (pola v1.26).
    // 'Pengaturan dompet' global TIDAK di sini.
    await tester.fling(
      find.byType(AccountDetailScreen),
      const Offset(0, -500),
      1000,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final settingAnchor = find.text('Dikelola keluarga');
    await tester.ensureVisible(settingAnchor);
    await tester.pump();
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Ganti nama'), findsOneWidget);
    expect(find.text('Saldo awal'), findsOneWidget);
    expect(find.text('Dikelola keluarga'), findsOneWidget);
    expect(find.byKey(ValueKey('detail:shared-$utamaId')), findsOneWidget);
    expect(find.text('Arsipkan dompet'), findsOneWidget);
    expect(find.text('Pengaturan dompet'), findsNothing);

    // v1.32.1: Catat = FAB (baris menu 'Catat di dompet ini' HAPUS);
    // tap FAB → form catat dgn dompet ini terpilih ('Catat ke').
    expect(find.text('Catat di dompet ini'), findsNothing);
    expect(find.byKey(ValueKey('detail:fab-$utamaId')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('detail:fab-$utamaId')));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(TxFormScreen), findsOneWidget);
    expect(find.text('Catat ke'), findsWidgets);

    await _flushDriftCloseTimer(tester);
  });

  // v1.32: toggle keluarga tulis isShared (default pribadi=false);
  // tap switch → ON → baris persist; round-trip sync map ikut flag.
  testWidgets('toggle keluarga persist isShared + sync map (v1.32)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    // Id dompet DINAMIS (backfill auto-increment, bukan 1) — baca dulu.
    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AccountDetailScreen(accountId: utamaId),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Lazy ListView: toggle di tail, belum di-build → fling paksa
    // build dulu (aturan v1.24.10), baru tap.
    await tester.fling(
      find.byType(AccountDetailScreen),
      const Offset(0, -500),
      1000,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Default: pribadi (false).
    var row = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.id == utamaId);
    expect(row.isShared, isFalse);
    // Tap switch → ON.
    await tester.tap(find.byKey(ValueKey('detail:shared-$utamaId')));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    row = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.id == utamaId);
    expect(row.isShared, isTrue);
    // Sync map ikut flag (push) + parse defensif (pull tanpa flag).
    final m = accountToMap(row, 'hid', 'uid');
    expect(m['isShared'], isTrue);
    final parsed = parseRemoteAccount({'uuid': 'u1', 'name': 'X'});
    expect(parsed?.isShared, isFalse);

    await _flushDriftCloseTimer(tester);
  });

  testWidgets('kosong (semua arsip): empty-state (v1.29)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(db.accounts).get()).firstWhere(
        (a) => a.name == 'Utama',
      );
      await archiveAccount(db, utama.id);
    });
    await _pumpCarousel(tester, db);

    expect(find.text('Belum ada dompet'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:carousel')), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Task 6 (integrasi, HomeScreen penuh):
  // geser kartu → top kategori ikut filter dompet tampil.
  testWidgets('integrasi: geser → top kategori ikut dompet (v1.29)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final bulanIni = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _loadFonts();
      final utama = (await db.select(db.accounts).get()).firstWhere(
        (a) => a.name == 'Utama',
      );
      final keluargaId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await reorderAccounts(db, [utama.id, keluargaId]);
      Future<void> tx(int amount, int cat, int accountId, String note) => db
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

  // Task 6 (integrasi v1.37): dock Catat ikut dompet yang sedang tampil.
  testWidgets('integrasi: dock Catat → tx dompet kedua', (
    tester,
  ) async {
    final db = await _newDb(tester);
    try {
      await tester.runAsync(() async {
        await _loadFonts();
        final utama = (await db.select(db.accounts).get()).firstWhere(
          (a) => a.name == 'Utama',
        );
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
            home: const AppShell(),
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // v1.37: pintu catat tunggal = dock tengah; form mewarisi filter
      // dompet yang sedang tampil (Keluarga).
      await tester.fling(
        find.byKey(const ValueKey('home:carousel')),
        const Offset(-350, 0),
        1000,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Keluarga'), findsOneWidget);
      // Dock Catat → form (filter = Keluarga).
      await tester.tap(find.bySemanticsLabel('Catat transaksi'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TxFormScreen), findsOneWidget);
      // Form TERLIHAT catat ke dompet mana (v1.32, request user).
      expect(find.text('Catat ke'), findsOneWidget);
      expect(find.text('Keluarga'), findsWidgets);
      // Isi nominal + simpan (kategori default pertama).
      await tester.enterText(find.byType(TextField).first, '25000');
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

  // v1.32.3: tap mata = toggle privacy SAJA — kartu tak boleh ikut buka
  // detail. Mata = SIBLING kartu di Stack luar (bukan anak Listener),
  // jadi tap-nya tak pernah fire onTap kartu (probe R7 sebelum fix:
  // PREF true + DETAIL true = fire ganda).
  testWidgets('mata saldo toggle tanpa buka detail (v1.32.3)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    final eyeHide = find.byTooltip('Sembunyikan saldo');
    expect(eyeHide, findsOneWidget);
    await tester.tap(eyeHide);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Toggle jalan (tooltip ganti; prefs ikut tertulis)...
    expect(find.byTooltip('Tampilkan saldo'), findsOneWidget);
    final prefs = (await tester.runAsync(
      () => SharedPreferences.getInstance(),
    ))!;
    expect(prefs.getBool('hide_balance'), isTrue);
    // ...tapi layar detail TIDAK ikut terbuka.
    expect(find.byType(AccountDetailScreen), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // v1.32.3: mata nempel pojok kanan kartu walau saldo sempit (Rp0).
  // Dulu Positioned(right:0) mengacu Stack selebar kolom isi (label
  // 179px) → mata mendarat di tengah kartu menimpa 'SALDO SAAT INI'
  // (probe KOSONG: eye 171-219 = label 40-219, OVERLAP true; SEED di
  // kanan 302-350 karena kolom lebar).
  testWidgets('mata di pojok kanan kartu saat saldo Rp0 (v1.32.3)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    await _pumpCarousel(tester, db);

    final utamaId = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!.firstWhere((a) => a.name == 'Utama').id;
    final eye = find.byTooltip('Sembunyikan saldo');
    expect(eye, findsOneWidget);
    final eyeRect = tester.getRect(eye);
    final cardRect = tester.getRect(
      find.byKey(ValueKey('home:card-$utamaId')),
    );
    // Pojok kanan kartu: tengah mata di sepertiga kanan + tepi kanan
    // sejajar isi kartu + tak menimpa label.
    expect(eyeRect.center.dx, greaterThan(300.0));
    expect(eyeRect.right, lessThanOrEqualTo(cardRect.right - 16.0));
    expect(
      eyeRect.overlaps(tester.getRect(find.text('SALDO SAAT INI'))),
      isFalse,
    );

    await _flushDriftCloseTimer(tester);
  });
}
