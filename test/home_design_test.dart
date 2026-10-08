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
  // Bulan ini.
  await tx(
    8500000,
    false,
    9,
    DateTime(now.year, now.month, 9, 8),
    note: 'Gaji',
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

    expect(find.text('Saldo semua waktu'), findsOneWidget);
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
  // Segoe — Row hero (357), kategori cepat (638), status budget (833)
  // jebol 31px di 390px. Viewport 300px mensimulasikan teks panjang
  // agar jebol duluan di lokal. Test gagal otomatis bila ada
  // RenderFlex overflow (Flutter melempar exception saat pump).
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
    expect(find.text('Saldo semua waktu'), findsOneWidget);
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
