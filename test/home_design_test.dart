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
import 'package:mywallet/ui/components/app_month_nav.dart';
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
  final db = (await tester.runAsync(
    () async => AppDatabase(NativeDatabase.memory()),
  ))!;
  addTearDown(db.close);
  return db;
}

Future<void> _seed(AppDatabase db) async {
  Future<void> tx(
    int amount,
    bool isExpense,
    int cat,
    DateTime date, {
    String note = '',
  }) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: Value(isExpense),
          categoryId: Value(cat),
          date: date,
          note: Value(note),
        ),
      );

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
  await tx(
    1688000,
    false,
    9,
    DateTime(now.year, now.month, 2),
    note: 'Bonus',
  );
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
  testWidgets('hero light: delta % vs bulan lalu + pacing budget', (
    tester,
  ) async {
    final db = await _newDb(tester);
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
    // Sapaan production-grade (v1.18): berbasis waktu + nama (manual →
    // Google → polos). Test tanpa login/nama = sapaan polos pagi/siang/
    // sore/malam — tanpa koma menggantung, tanpa nama mockup.
    expect(find.textContaining('Selamat '), findsOneWidget);
    expect(find.text('Hai, Nievi'), findsNothing);
    expect(find.text('Sisa budget'), findsOneWidget);
    // Delta dari provider (bukan FutureBuilder) — harus ter-render.
    expect(find.textContaining('vs '), findsWidgets);
    expect(find.textContaining('Pengeluaran turun'), findsOneWidget);
    // Pacing budget.
    expect(find.textContaining('dari Rp'), findsOneWidget);
    expect(find.textContaining('Aman'), findsOneWidget);

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
  testWidgets('hero: dua pil catat membuka tipe form yang benar', (
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

    expect(find.text('Detail'), findsNothing,
        reason: 'pill Detail (alias Laporan) harus dihapus');
    expect(find.text('+ Catat keluar'), findsOneWidget);
    expect(find.text('+ Pemasukan'), findsOneWidget);
    // Lonceng lama dihapus — ia cuma snackbar, bukan jalan ke fitur
    // Pengingat harian yang hidup di Pengaturan.
    expect(find.byTooltip('Notifikasi'), findsNothing);
    // Avatar bukan tombol — satu-satunya pintu Pengaturan = gear.
    expect(find.byTooltip('Profil'), findsNothing);
    expect(find.byTooltip('Pengaturan'), findsOneWidget);
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
    // Nama kategori muncul tepat SEKALI (di seksi Top, bukan 2x:
    // strip + seksi seperti v1.14.x awal).
    expect(find.text('Makan & Minum'), findsOneWidget);
    await _flushDriftCloseTimer(tester);
  });

  // Regresi kritik brutal v1.14.x (4): tile ketiga tanpa budget tidak
  // lagi kartu "— / belum diatur" setinggi tile bernilai.
  testWidgets('tile budget kosong = ajakan ringkas, bukan kartu hampa', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db); // tanpa budget
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

    expect(find.text('Belum diatur'), findsOneWidget);
    expect(find.text('—'), findsNothing);
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
      expect(income, isNot(equals(expense)),
          reason: 'Masuk tidak boleh sama dengan Keluar (aksen merah)');
      // Kontras vs surface kartu di tema aktif.
      final surface = t.cardTheme.color ?? t.colorScheme.surface;
      expect(ratio(income, surface), greaterThanOrEqualTo(4.5));
    }
    await _flushDriftCloseTimer(tester);
  });

  testWidgets('hero dark tanpa budget: CTA "Atur budget" → tab 2', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db); // tanpa budget
    });

    var tab = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeScreen(onGoTab: (i) => tab = i),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Belum ada budget bulan ini'), findsOneWidget);
    await tester.tap(find.text('Atur budget'));
    await tester.pump();
    expect(tab, 2, reason: 'CTA harus lompat ke tab Budget');

    if (_runGolden) {
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_dark_nobudget.png'),
      );
    }
    await _flushDriftCloseTimer(tester);
  });

  // Pengganti "lihat matanya": kontras WCAG diukur eksplisit, karena
  // kartu saldo kini GRADIENT IKUT AKSEN TEMA (hijau default, biru
  // ala GoPay, dst) di DUA kecerahan — aksen mode gelap itu TERANG,
  // jadi diukur dari widget yang benar-benar dirender: dua ujung
  // gradien (ber-key 'home:hero') + latar kepala ('home:header'),
  // untuk 6 aksen × 2 tema = 24 pengukuran.
  testWidgets('kontras putih vs kartu+kepala minimal 4.5:1 (semua aksen)', (
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

    final db = await _newDb(tester);
    await tester.runAsync(() async {
      await _loadFonts();
      await _seed(db);
    });

    final hasil = <String, double>{};
    for (final e in AppTheme.accentOptions.entries) {
      final temas = <String, ThemeData>{
        'light': AppTheme.light(seed: e.value.color),
        'dark': AppTheme.dark(seed: e.value.color),
      };
      for (final t in temas.entries) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp(theme: t.value, home: const HomeScreen()),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final hero = tester.widget<Container>(
          find.byKey(const ValueKey('home:hero')),
        );
        final grad =
            (hero.decoration! as BoxDecoration).gradient! as LinearGradient;
        for (var i = 0; i < grad.colors.length; i++) {
          hasil['${e.key}/${t.key} kartu$i'] = ratio(
            Colors.white,
            grad.colors[i],
          );
        }
        final kepala = tester.widget<Container>(
          find.byKey(const ValueKey('home:header')),
        );
        hasil['${e.key}/${t.key} kepala'] = ratio(Colors.white, kepala.color!);
      }
    }
    hasil.forEach(
      (label, r) => expect(r, greaterThanOrEqualTo(4.5), reason: label),
    );
    final worst = hasil.entries.reduce((a, b) => a.value < b.value ? a : b);
    debugPrint(
      'kontras minimum ${worst.value.toStringAsFixed(2)}:1 '
      '(${worst.key}) — ${hasil.length} pengukuran lolos ≥4.5:1',
    );
    await _flushDriftCloseTimer(tester);
  });

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
}

/// Lepas tree, lalu flush timer 0ms dari drift
/// (StreamQueryStore.markAsClosed) — tanpa ini binding test gagal di
/// invariant "A Timer is still pending". Bukan bug aplikasi.
Future<void> _flushDriftCloseTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
