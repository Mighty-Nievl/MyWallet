// Test v1.34.0 — kartu arus kas Beranda (Pemasukan & Pengeluaran).
//
// Kontrak yang dikunci:
// - Dua kartu terpisah, bukan diselipkan ke kartu saldo (yang tinggi tetap
//   116px dan sudah overflow di font besar).
// - Nominal mengikuti privacy + gaya kompak dari [displayPrefsProvider].
// - Delta dihitung terhadap periode sebelumnya, dan TIDAK membocorkan
//   arah arus saat privacy menyembunyikan semua nominal.
// - Aman di textScaler 2.0 (FittedBox + ellipsis; tanpa overflow).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/settings.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/history_screen.dart';
import 'package:mywallet/ui/widgets/flow_cards.dart';

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.customSelect('SELECT 1').get();
    return d;
  });
  return db!;
}

/// Pump kartu saja (tanpa Beranda) supaya exception yang muncul pasti
/// milik widget ini — bukan overflow Beranda yang sudah tercatat di
/// docs/06-Roadmap.md.
Future<void> _pumpCards(
  WidgetTester tester,
  AppDatabase db, {
  int masuk = 1000,
  int keluar = 400,
  int? prevMasuk = 800,
  int? prevKeluar = 500,
  bool hide = false,
  String scope = 'balance',
  double? scale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        // v1.36.0: kartu ikut periode aktif, bukan bulan.
        periodTotalsProvider.overrideWith(
          (ref) => Stream.value((masuk, keluar)),
        ),
        prevPeriodTotalsProvider.overrideWith(
          (ref) => Stream.value((
            prevMasuk ?? 0,
            prevKeluar ?? 0,
          )),
        ),
        hideBalanceProvider.overrideWith((ref) async => hide),
        privacyScopeProvider.overrideWith((ref) async => scope),
        compactAmountsProvider.overrideWith((ref) async => false),
        relativeDatesProvider.overrideWith((ref) async => true),
        showCategoryIconsProvider.overrideWith((ref) async => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: scale == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: FlowCards(),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _cleanup(WidgetTester tester, AppDatabase db) async {
  try {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => db.close());
  } catch (_) {}
}

void main() {
  testWidgets('dua kartu terpisah + nominal periode aktif', (tester) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db);

    expect(find.byKey(const ValueKey('home:flow-income')), findsOneWidget);
    expect(find.byKey(const ValueKey('home:flow-expense')), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Rp1.000'), findsOneWidget);
    expect(find.text('Rp400'), findsOneWidget);

    // 1000 vs 800 = +25%; 400 vs 500 = -20%.
    expect(find.text('▲ 25% dari bulan lalu'), findsOneWidget);
    expect(find.text('▼ 20% dari bulan lalu'), findsOneWidget);

    await _cleanup(tester, db);
  });

  testWidgets('privacy semua nominal: angka & arah arus disamarkan', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db, hide: true, scope: 'all');

    expect(find.text('Rp••••'), findsNWidgets(2));
    expect(find.text('perubahan disembunyikan'), findsNWidgets(2));
    // Persen TIDAK boleh muncul: arah arus pun informasi.
    expect(find.textContaining('% dari bulan lalu'), findsNothing);

    await _cleanup(tester, db);
  });

  testWidgets('periode lalu nol: tidak membagi nol', (tester) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db, prevMasuk: 0, prevKeluar: 0);

    expect(find.text('baru periode ini'), findsNWidgets(2));
    expect(find.textContaining('Infinity'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);

    await _cleanup(tester, db);
  });

  testWidgets('tap kartu pengeluaran membuka Riwayat terfilter keluar', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db);

    await tester.tap(find.byKey(const ValueKey('home:flow-expense')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HistoryScreen), findsOneWidget);
    final ctx = tester.element(find.byType(HistoryScreen));
    expect(
      ProviderScope.containerOf(ctx).read(historyFilterProvider).isExpense,
      isTrue,
    );

    await _cleanup(tester, db);
  });

  testWidgets('tap kartu pemasukan membuka Riwayat terfilter masuk', (
    tester,
  ) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db);

    await tester.tap(find.byKey(const ValueKey('home:flow-income')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HistoryScreen), findsOneWidget);
    final ctx = tester.element(find.byType(HistoryScreen));
    expect(
      ProviderScope.containerOf(ctx).read(historyFilterProvider).isExpense,
      isFalse,
    );

    await _cleanup(tester, db);
  });

  testWidgets('textScaler 2.0: tidak ada overflow dari kartu', (tester) async {
    final db = await _newDb(tester);
    await _pumpCards(tester, db, scale: 2.0);

    // Kartu dipompa sendirian: exception apa pun di sini milik kartu ini.
    expect(tester.takeException(), isNull);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);

    await _cleanup(tester, db);
  });
}
