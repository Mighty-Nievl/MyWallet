// Regresi desain Beranda — jalankan: flutter test test/home_design_test.dart
// Menangkap 3 perbaikan: delta % vs bulan lalu (provider, bukan
// FutureBuilder), CTA budget saat kosong, dan strip hari ini.
//
// Golden (PNG) cuma stabil di SATU OS + font yang sama — file di
// test/goldens/ dibuat di Windows (font Segoe) dan hanya dibandingkan
// di lokal. Di CI (Ubuntu, font DejaVu) pixel diff pasti besar walau
// layout sama, jadi golden di-skip otomatis dan assertion perilaku
// (teks delta, CTA, kontras WCAG) tetap jalan penuh.

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/components/app_feedback.dart';
import 'package:mywallet/ui/components/app_month_nav.dart';
import 'package:mywallet/ui/components/setting_row.dart';
import 'package:mywallet/ui/design/app_colors.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Golden (PNG) cuma stabil di SATU OS + font yang sama — file di
/// test/goldens/ dibuat di Windows dan hanya dibandingkan di lokal
/// (`flutter test --dart-define=GOLDEN=true`). Di CI (Ubuntu, font
/// DejaVu) pixel diff pasti besar walau layout sama, jadi golden
/// di-skip otomatis dan assertion perilaku tetap jalan penuh.
const _runGolden = bool.fromEnvironment('GOLDEN', defaultValue: false);

const _win = 'C:\\Windows\\Fonts';

Future<void> _loadFonts() async {
  Future<void> load(String family, String file) async {
    final f = File(file);
    if (!await f.exists()) return; // mesin lain: biarkan font fallback
    final bytes = await f.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('Roboto', '$_win\\segoeui.ttf');
  await load('Roboto', '$_win\\segoeuib.ttf');
  await load(
    'MaterialIcons',
    'E:\\dev\\flutter\\bin\\cache\\artifacts\\material_fonts'
        '\\materialicons-regular.otf',
  );
}

Future<AppDatabase> _newDb(WidgetTester tester, {Size? size}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size ?? const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = (await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.backfillAccounts(); // seed Utama (v1.25)
    return d;
  }))!;
  addTearDown(db.close);
  return db;
}

/// Id dompet Utama (di-seed _newDb) — v1.25: helper tx WAJIB isi ini.
Future<int> _utama(AppDatabase db) async => (await db.select(db.accounts).get())
    .firstWhere((a) => a.name == 'Utama')
    .id;

Future<void> _seed(AppDatabase db) async {
  Future<void> tx(
    int amount,
    bool isExpense,
    int cat,
    DateTime date, {
    String note = '',
  }) async {
    final utama = await _utama(db);
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: amount,
            isExpense: Value(isExpense),
            categoryId: Value(cat),
            date: date,
            note: Value(note),
            accountId: Value(utama),
          ),
        );
  }

  final now = DateTime.now();
  final bulanIni = DateTime(now.year, now.month, now.day);
  // Bulan lalu sengaja diisi → delta % di hero punya bahan.
  await tx(
    1200000,
    true,
    3,
    DateTime(now.year, now.month - 1, 5),
    note: 'Beban bulan lalu',
  );
  // Bulan ini. Total harus pas Rp8.925.000 ala mockup:
  // 8.500.000 + 1.688.000 − 45.000 − 18.000 − 1.200.000 (bulan lalu).
  await tx(
    8500000,
    false,
    9,
    DateTime(now.year, now.month, 9, 8),
    note: 'Gaji',
  );
  await tx(1688000, false, 9, DateTime(now.year, now.month, 2), note: 'Bonus');
  await tx(45000, true, 1, bulanIni, note: 'Makan siang');
  await tx(
    18000,
    true,
    2,
    bulanIni.add(const Duration(hours: 7)),
    note: 'Ojek',
  );
}

Future<void> _budget(AppDatabase db, int limit) async {
  final now = DateTime.now();
  await db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          categoryId: 1,
          limit: limit,
          month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        ),
      );
}

void main() {
  testWidgets('hero light minimalis: saldo + 1 CTA (redesign v1.24)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.text('SALDO SAAT INI'), findsOneWidget);
    // Redesign v1.24: sapaan + delta + budget DIHAPUS dari hero.
    expect(find.textContaining('Selamat '), findsNothing);
    expect(find.text('Sisa budget'), findsNothing);
    expect(find.textContaining('vs '), findsNothing);
    expect(find.textContaining('dari Rp'), findsNothing);
    // Hero minimalis: CUMA saldo + 1 CTA "Catat keluar".
    expect(find.text('+ Catat keluar'), findsOneWidget);
    expect(find.text('+ Pemasukan'), findsNothing);

    if (_runGolden) {
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_light.png'),
      );
    }
    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (1): hero hanya punya DUA aksi
  // pencatatan dengan tujuan berbeda — pill "Detail" (alias tab Laporan)
  // dihapus; "+ Catat keluar" membuka form pengeluaran,
  // "+ Pemasukan" membuka form pemasukan (v1.13.x keduanya membuka
  // form pengeluaran yang sama).
  testWidgets('hero: tombol catat keluar membuka form pengeluaran', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.text('+ Catat keluar'), findsOneWidget);
    expect(find.text('+ Pemasukan'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (2): nav bulan SELALU tampil
  // (chicken-and-egg v1.13.x: AppMonthNav cuma dirender saat bulan lain,
  // padahal ia satu-satunya penulis selectedMonthProvider di Beranda).
  testWidgets('nav bulan selalu tampil di bulan berjalan', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.byKey(const ValueKey('home:monthnav')), findsOneWidget);
    expect(find.byType(AppMonthNav), findsOneWidget);
    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (3): SATU blok kategori per layar.
  // Strip "Top kategori" (duplikat 5 baris pertama seksi Top, sumber
  // data sama) dihapus — seksi "Pengeluaran bulan ini" satu-satunya
  // wajah kategori di Beranda. Jalan ke Riwayat terfilter tetap ada
  // lewat seksi Top? Tidak — Top tidak memfilter; filter kategori
  // milik tab Riwayat sendiri. Test ini mengunci: tidak ada duplikat.
  testWidgets('tidak ada blok kategori ganda di beranda', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db); // bulan ini: Makan siang (cat 1) + Ojek (cat 2)
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

    // Label strip ganda (lama "Kategori cepat", baru "Top kategori")
    // tidak boleh ada — seksi memakai judul "Pengeluaran bulan ini".
    expect(find.text('Kategori cepat'), findsNothing);
    expect(find.text('Top kategori'), findsNothing);
    expect(find.text('Pengeluaran bulan ini'), findsOneWidget);
    // Nama kategori muncul di seksi Top (judul, bodyLarge w600).
    // v1.24.4: subtitle tile Beranda = nama kategori polos (tanggal
    // disembunyikan, showDate:false) → exact-match 2x itu benar per
    // desain baru (judul seksi + subtitle tile), bukan blok ganda
    // ala v1.14.x (strip "Kategori cepat" + seksi Top).
    expect(find.text('Makan & Minum'), findsNWidgets(2));
    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (4): tile ketiga tanpa budget tidak
  // lagi kartu "— / belum diatur" setinggi tile bernilai.
  testWidgets('tile budget kosong (dihapus v1.24)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    // Redesign v1.24: budget tile dihapus dari Beranda.
    expect(find.text('Sisa budget'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (5): hijau pemasukan TETAP
  // (tidak ikut aksen tema) — kontras ≥4.5:1 di kedua tema, dan tidak
  // pernah sama dengan merah pengeluaran walau aksen = merah.
  testWidgets('income hijau tetap kontras di kedua tema', (tester) async {
    double lum(Color c) {
      double f(double v) =>
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double ratio(Color a, Color b) {
      final hi = max(lum(a), lum(b));
      final lo = min(lum(a), lum(b));
      return (hi + 0.05) / (lo + 0.05);
    }

    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
    });

    // Aksen merah = kasus terburuk v1.13.x (Masuk == Keluar == merah).
    for (final t in [
      AppTheme.light(seed: const Color(0xFFDC2626)),
      AppTheme.dark(seed: const Color(0xFFDC2626)),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: t, home: const HomeScreen()),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final ctx = tester.element(find.byType(HomeScreen));
      final income = AppColors.incomeOf(ctx);
      final expense = AppColors.expenseOf(ctx);
      expect(
        income,
        isNot(equals(expense)),
        reason: 'Masuk tidak boleh sama dengan Keluar (aksen merah)',
      );
      // Kontras vs surface kartu di tema aktif.
      final surface = t.cardTheme.color ?? t.colorScheme.surface;
      expect(ratio(income, surface), greaterThanOrEqualTo(4.5));
    }
    await _flushDriftCloseTimer(tester);
  });

  testWidgets('hero dark minimalis tanpa budget (redesign v1.24)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeScreen(onGoTab: (_) {}),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Sisa budget'), findsNothing);
    expect(find.text('Belum diatur'), findsNothing);
    expect(find.text('Atur budget'), findsNothing);

    if (_runGolden) {
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_dark.png'),
      );
    }
    await _flushDriftCloseTimer(tester);
  });

  // Regresi audit visual v1.24.1: teks CTA "+ Catat keluar" di atas
  // primary HARUS ≥4.5:1 di 6 aksen × 2 tema. Insiden: foreground
  // putih hardcode jebol di dark mode (primary = mint terang).
  // Fix: foreground = onPrimary. Test ini mengunci kontraknya.
  testWidgets('kontras teks CTA vs primary minimal 4.5:1 (semua aksen)', (
    tester,
  ) async {
    double lum(Color c) {
      double f(double v) =>
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double ratio(Color a, Color b) {
      final hi = max(lum(a), lum(b));
      final lo = min(lum(a), lum(b));
      return (hi + 0.05) / (lo + 0.05);
    }

    final hasil = <String, double>{};
    for (final e in AppTheme.accentOptions.entries) {
      final temas = <String, ThemeData>{
        'light': AppTheme.light(seed: e.value.color),
        'dark': AppTheme.dark(seed: e.value.color),
      };
      for (final t in temas.entries) {
        // Kontrak kode: bg = scheme.primary, fg = scheme.onPrimary
        // (home_screen.dart _HeroCard). Ukur pasangan yang sama.
        final r = ratio(
          t.value.colorScheme.onPrimary,
          t.value.colorScheme.primary,
        );
        hasil['${e.key}/${t.key} cta'] = r;
      }
    }
    hasil.forEach(
      (label, r) => expect(r, greaterThanOrEqualTo(4.5), reason: label),
    );
    final worst = hasil.entries.reduce((a, b) => a.value < b.value ? a : b);
    debugPrint(
      'kontras CTA minimum ${worst.value.toStringAsFixed(2)}:1 '
      '(${worst.key}) — ${hasil.length} pengukuran lolos ≥4.5:1',
    );
  });

  // (Riwayat: test kontras gradien hero v1.23 di-skip di v1.24 karena
  // hero ganti kartu putih bersih — blok comment lama dihapus di sini.)

  // Regresi overflow CI v1.13.0: font fallback Linux lebih lebar dari
  // Segoe — Row hero, status budget jebol di 390px. Viewport 300px
  // mensimulasikan teks panjang agar jebol duluan di lokal. Test gagal
  // otomatis bila ada RenderFlex overflow (Flutter melempar saat pump).
  testWidgets('tidak overflow di viewport sempit 300px', (tester) async {
    final db = await _newDb(tester, size: const Size(300, 844));
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
      await _budget(db, 2000000);
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
    expect(find.text('SALDO SAAT INI'), findsOneWidget);
    await _flushDriftCloseTimer(tester);
  });

  // B2C: budget bulan ini DIHITUNG DI AWAL — baris pacing ada di hero
  // (sumber sama budgetsProvider), bukan cuma di tile bawah.
  testWidgets('hero minimalis tanpa pacing budget (redesign v1.24)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.text('Sisa budget'), findsNothing);
    expect(find.textContaining('dari Rp'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Simple-minimalis (v1.23): kartu streak DIHAPUS atas permintaan
  // user — Beranda tanpa gamifikasi. Test ini mengunci: tidak ada teks
  // streak/dots di Beranda walau ada transaksi hari ini.
  testWidgets('tidak ada kartu streak di beranda', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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
    expect(find.textContaining('Streak'), findsNothing);
    expect(find.textContaining('/7'), findsNothing);
    await _flushDriftCloseTimer(tester);
  });

  // B2C: Catat Kilat — chip nominal membuka form pengeluaran dengan
  // nominal SUDAH terisi (initialAmount).
  testWidgets('catat kilat dihapus (redesign v1.24)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.text('Catat kilat'), findsNothing);
    expect(find.text('Rp10 rb'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Rapikan list v1.24.4 (kritik brutal screenshot Beranda): tanggal
  // TIDAK diulang di tiap baris grup ("Makan siang · Hari ini" no more).
  // Seed: 'Makan siang' (cat 1, hari ini) → judul = note, subtitle =
  // nama kategori polos, tanpa suffix tanggal.
  testWidgets('subtitle tile beranda tanpa tanggal (rapi v1.24.4)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db); // 'Makan siang' + 'Ojek', keduanya hari ini
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

    // Judul (note) tetap ada.
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Ojek'), findsOneWidget);
    // Subtitle redundan tanggal per baris SUDAH tidak ada.
    expect(find.textContaining('Makan & Minum ·'), findsNothing);
    expect(find.textContaining('Transportasi ·'), findsNothing);
    expect(find.textContaining('· Hari ini'), findsNothing);
    expect(find.textContaining('· Kemarin'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Audit arsitektur v1.24.5 fix 1 (kritik screenshot: tepi kanan
  // -Rp8.000 mundur vs -Rp300.000 + chevron wobble). Seed: 'Makan siang'
  // Rp45.000 vs 'Ojek' Rp18.000 — digit beda → tepi kanan HARUS sejajar.
  testWidgets('nominal tile rata kanan sejajar (fix v1.24.5)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db); // 45.000 (6 digit) vs 18.000 (6 digit beda pola)
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

    // Ambil posisi kanan kedua nominal — Expanded + textAlign.end
    // menjamin sejajar (toleransi 1px render).
    final r45 = tester.getRect(find.text('-Rp45.000'));
    final r18 = tester.getRect(find.text('-Rp18.000'));
    expect((r45.right - r18.right).abs(), lessThan(1.0));

    await _flushDriftCloseTimer(tester);
  });

  // Audit arsitektur v1.24.5 fix 3: strip ringkasan SATU baris, label
  // "Hari ini" depan dihapus (tanggal ikut header grup). Seed hari ini:
  // masuk Rp10.188.000 (Gaji+Bonus) · keluar Rp63.000.
  testWidgets('strip ringkasan satu baris tanpa label Hari ini (v1.24.5)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    // Baris ringkasan baru: "Masuk ... · Keluar ..." (kapital, 1 baris).
    expect(find.textContaining('Masuk +Rp'), findsOneWidget);
    expect(find.textContaining('Keluar -Rp'), findsOneWidget);
    // Label lama lowercase + dobel "Hari ini" depan SUDAH tidak ada.
    expect(find.textContaining('masuk +Rp'), findsNothing);
    expect(find.textContaining('keluar -Rp'), findsNothing);

    await _flushDriftCloseTimer(tester);
  });

  // Opsi A v1.24.6: header bukan baris yatim 1 gear — wordmark kiri +
  // gear kanan via AppHeader shared (pola Riwayat).
  testWidgets('header beranda wordmark + gear sejajar (opsi A)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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

    expect(find.text('MyWallet'), findsOneWidget);
    expect(find.byTooltip('Pengaturan'), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // v1.24.8: tombol header polos — gear + chevron + mata tanpa kotak,
  // tombol kembali tetap berboder (butuh body navigasi).
  testWidgets('tombol header polos, tombol kembali berboder (v1.24.8)', (
    tester,
  ) async {
    // Gear (AppHeader via Beranda) = polos.
    final gear = AppIconButton(
      icon: Icons.settings_outlined,
      onPressed: () {},
      tooltip: 'Pengaturan',
      bordered: false,
    );
    // Kembali (BackHeader) = default berboder.
    const back = BackHeader(title: 'Kembali');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Column(children: [gear, back])),
      ),
    );
    await tester.pump();

    // Polos: tidak ada Container berboder di atas IconButton gear.
    final gearBtn = find.byTooltip('Pengaturan');
    expect(gearBtn, findsOneWidget);
    // Berboder: BackHeader masih pakai AppIconButton default (kotak ada).
    expect(find.text('Kembali'), findsOneWidget);
    // Default flag tetap true — pemakai lama tidak berubah visual.
    expect(
      const AppIconButton(icon: Icons.add, onPressed: null).bordered,
      isTrue,
    );
  });

  // v1.25: 1 dompet = strip penuh tapi ramping (Semua + Utama +
  // Kelola, 1 baris horizontal). Konsisten + Kelola reachable.
  testWidgets('pemilih dompet hilang bila 1 dompet (v1.25)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
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
    expect(find.text('SALDO SAAT INI'), findsOneWidget);
    expect(find.byKey(const ValueKey('home:accounts')), findsOneWidget);
    // Strip ramping 1 baris: Semua + Utama + Kelola.
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Kelola'), findsOneWidget);
    expect(find.text('Utama'), findsOneWidget);
    await _flushDriftCloseTimer(tester);
  });

  // v1.25: 2 dompet = chip Semua + nama + Kelola; tap = filter jalan.
  testWidgets('pemilih dompet 2 dompet: tap filter (v1.25)', (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      await _seed(db);
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
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Keluarga'), findsOneWidget);
    expect(find.text('Kelola'), findsOneWidget);
    // Tap Keluarga → chip terseleksi (filter global aktif).
    await tester.tap(find.text('Keluarga'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Keluarga'), findsOneWidget);
    await _flushDriftCloseTimer(tester);
  });
}

/// Lepas tree, lalu flush timer 0ms dari drift
/// (StreamQueryStore.markAsClosed) — tanpa ini binding test gagal di
/// invariant "A Timer is still pending". Bukan bug aplikasi.
Future<void> _flushDriftCloseTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
