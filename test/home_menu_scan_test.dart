// Regression v1.26: grid menu Beranda 4x2 + nav 3 tombol + pintu catat
// tunggal + layar push punya tombol kembali.
//
// Kontrak yang dikunci:
// - Grid `home:features`: 8 item (4 aksi + 4 pintas), label grup
//   "Aksi cepat"/"Lihat", tap tiap item buka tujuan yang benar.
// - Shell: Beranda + tombol tengah (Catat transaksi) + Scan; tab lama
//   (Riwayat/Budget/Laporan/Utang) + FAB hilang.
// - Layar push (Riwayat/Budget/Laporan/Utang) punya tombol Kembali.
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/receipt_parse.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/design/app_colors.dart';
import 'package:mywallet/ui/scan_flow.dart';
import 'package:mywallet/ui/screens/accounts_screen.dart';
import 'package:mywallet/ui/screens/budget_screen.dart';
import 'package:mywallet/ui/screens/debt_screen.dart';
import 'package:mywallet/ui/screens/history_screen.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
import 'package:mywallet/ui/screens/reports_screen.dart';
import 'package:mywallet/ui/screens/tx_form_screen.dart';
import 'package:mywallet/ui/shell.dart';

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

Future<void> _pump(WidgetTester tester, {int ticks = 30}) async {
  for (var i = 0; i < ticks; i++) {
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

Future<void> _pumpHome(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    ),
  );
  await _pump(tester);
}

void main() {
  // Regresi audit visual v1.24.1 (pola test kontras CTA): ikon
  // scheme.onPrimary di atas lingkaran aksi (hijau masuk / merah keluar /
  // primer) HARUS ≥4.5:1 di 6 aksen × 2 tema. Diukur dengan context tema
  // asli (incomeOf/expenseOf baca isDark + Theme.of) — jangan eyeball.
  testWidgets('kontras ikon aksi vs lingkaran minimal 4.5:1 (semua aksen)',
      (tester) async {
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

    for (final e in AppTheme.accentOptions.entries) {
      for (final mode in ['light', 'dark']) {
        final theme = mode == 'light'
            ? AppTheme.light(seed: e.value.color)
            : AppTheme.dark(seed: e.value.color);
        late Map<String, double> hasil;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (ctx) {
                final fg = Theme.of(ctx).colorScheme.onPrimary;
                hasil = <String, double>{
                  'income': ratio(fg, AppColors.incomeOf(ctx)),
                  'expense': ratio(fg, AppColors.expenseOf(ctx)),
                  'primary': ratio(
                    fg,
                    Theme.of(ctx).colorScheme.primary,
                  ),
                };
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();
        hasil.forEach(
          (label, r) => expect(
            r,
            greaterThanOrEqualTo(4.5),
            reason: '${e.key}/$mode $label',
          ),
        );
      }
    }
  });

  testWidgets('grid 4x2: 8 item + 2 label grup (v1.26)', (tester) async {
    final db = await _newDb(tester);
    try {
      await _pumpHome(tester, db);
      expect(find.byKey(const ValueKey('home:features')), findsOneWidget);
      expect(find.text('Aksi cepat'), findsOneWidget);
      expect(find.text('Lihat'), findsOneWidget);
      for (final label in [
        'Catat masuk',
        'Catat keluar',
        'Pindah dana',
        'Scan struk',
        'Riwayat',
        'Budget',
        'Laporan',
        'Utang',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('aksi Catat keluar buka form pengeluaran (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await _pumpHome(tester, db);
      await tester.tap(find.text('Catat keluar'));
      await _pump(tester);
      expect(find.byType(TxFormScreen), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('aksi Pindah dana buka transfer sheet (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.runAsync(() async {
        await db.into(db.accounts).insert(
              AccountsCompanion.insert(name: 'Keluarga'),
            );
      });
      await _pumpHome(tester, db);
      await tester.tap(find.text('Pindah dana'));
      await _pump(tester);
      expect(find.byType(TransferSheet), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('pintas Riwayat push + tombol Kembali pulang (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await _pumpHome(tester, db);
      await tester.tap(find.text('Riwayat').first);
      await _pump(tester);
      expect(find.byType(HistoryScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await _pump(tester);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(find.byKey(const ValueKey('home:features')), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('pintas Budget/Laporan/Utang push + Kembali (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await _pumpHome(tester, db);
      final targets = <String, Type>{
        'Budget': BudgetScreen,
        'Laporan': ReportsScreen,
        'Utang': DebtScreen,
      };
      for (final e in targets.entries) {
        await tester.tap(find.text(e.key).first);
        await _pump(tester);
        expect(find.byType(e.value), findsOneWidget);
        await tester.tap(find.byTooltip('Kembali'));
        await _pump(tester);
        expect(find.byType(e.value), findsNothing);
      }
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('shell: Riwayat + Catat tengah + Scan, Beranda pensiun (v1.29.1)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
        ),
      );
      await _pump(tester);
      // Slot kiri navbar = pintasan Riwayat (tap → HistoryScreen).
      // 'Riwayat' juga ada di grid Beranda → scope ke navbar.
      final navRiwayat = find.descendant(
        of: find.byKey(const ValueKey('home:navbar')),
        matching: find.text('Riwayat'),
      );
      expect(navRiwayat, findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Catat transaksi'),
        findsOneWidget,
      );
      // v1.32.1: dock kompak 232×56 centered (koreksi "lebar" =
      // bentang horizontal, bukan tinggi). Target slot 116×56 >>
      // touchMin 48; + tetap hero 72. Ukur isi via teks Riwayat
      // (key navbar = Container, rect ikut margin bawah 12 + border).
      final navRect = tester.getRect(navRiwayat);
      expect(navRect.height, lessThanOrEqualTo(56.0));
      // Dock centered: lebar bar 232 (bukan full-width 358) — kunci
      // horizontal via key navbar.
      final barRect = tester.getRect(
        find.byKey(const ValueKey('home:navbar')),
      );
      expect(barRect.width, lessThanOrEqualTo(232.0));
      // v1.32.2 (regresi blank-screen: Center/Align di bottomNavigationBar
      // mengembang penuhi slot vertikal Scaffold → body height = 0.
      // Bukti probe: dock tengah 387-457 + body kosong walau header ada
      // di tree. Row-centered hanya bungkus horizontal. Kunci: body ada
      // + dock di bawah + centered.)
      expect(find.byKey(const ValueKey('home:header')), findsOneWidget);
      expect(barRect.bottom, greaterThan(750.0));
      expect(barRect.center.dx, closeTo(195.0, 2.0));
      // Beranda pensiun dari navbar (redundant: tap-nya dulu no-op).
      expect(find.text('Beranda'), findsNothing);
      // Tab lama + FAB gone (pintu catat tunggal = tombol tengah).
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      // Tap Riwayat navbar → layar Riwayat terbuka, tombol Kembali
      // pulang ke Beranda.
      await tester.tap(navRiwayat);
      await _pump(tester);
      expect(find.byType(HistoryScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await _pump(tester);
      expect(find.byType(HistoryScreen), findsNothing);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('tombol tengah buka form catat (v1.26)', (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
        ),
      );
      await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Catat transaksi'));
      await _pump(tester);
      expect(find.byType(TxFormScreen), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('pratinjau scan: banner + simpan ke dompet aktif (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ScanPreviewScreen(
              draft: ReceiptDraft(amount: 25000, merchant: 'Indomaret'),
              rawText: 'INDOMARET\nTOTAL 25.000',
            ),
          ),
        ),
      );
      await _pump(tester);
      expect(
        find.text('Hasil tebakan — periksa dulu sebelum simpan.'),
        findsOneWidget,
      );
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text('Indomaret'), findsOneWidget);
      // Koreksi manual lalu simpan.
      await tester.enterText(find.byType(TextField).first, '30.000');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Simpan'));
      await _pump(tester, ticks: 40);
      final txs = (await tester.runAsync(
        () => db.select(db.transactions).get(),
      ))!;
      expect(txs.length, 1);
      expect(txs.first.amount, 30000);
      final utama = ((await tester.runAsync(
        () => db.select(db.accounts).get(),
      ))!)
          .firstWhere((a) => a.name == 'Utama')
          .id;
      expect(txs.first.accountId, utama);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('pratinjau scan: teks mentah tampil di expander (v1.26)',
      (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ScanPreviewScreen(
              draft: ReceiptDraft(),
              rawText: 'TOKO ABC\nTOTAL 10.000',
            ),
          ),
        ),
      );
      await _pump(tester);
      await tester.tap(find.text('Lihat teks struk'));
      await _pump(tester);
      expect(find.textContaining('TOKO ABC'), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  // v1.32.4 (audit foto user): lingkaran 72 top -16 = 15px kepala + glow
  // di atas kapsul mengiris teks body ('Makan & Minu[m]', persen,
  // nominal — 5 hits probe). Fix: lingkaran 56 flush DALAM kapsul
  // (tak ada piksel di atas dock) + extendBody false (body berhenti di
  // atas slot) + bottomPad 112. Kunci REALISTIS floating dock: lingkaran
  // tak nongol + diam mentok-bawah bersih (tengah scroll konten lewat =
  // wajar, bukan bug).
  testWidgets('lingkaran + tidak menutupi teks body (v1.32.4)', (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.runAsync(() async {
        final utama = (await db.select(db.accounts).get())
            .firstWhere((a) => a.name == 'Utama')
            .id;
        final now = DateTime.now();
        for (var i = 0; i < 12; i++) {
          await db
              .into(db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  amount: 8925000 - i * 15000,
                  isExpense: Value(i.isEven),
                  categoryId: Value((i % 8) + 1),
                  date: DateTime(now.year, now.month, now.day - (i ~/ 4)),
                  note: Value('Jajan $i'),
                  accountId: Value(utama),
                ),
              );
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
        ),
      );
      await _pump(tester);
      final barRect = tester.getRect(
        find.byKey(const ValueKey('home:navbar')),
      );
      final catatRect = tester.getRect(
        find.bySemanticsLabel('Catat transaksi'),
      );
      // Lingkaran duduk DALAM kapsul: tak nongol di atas dock.
      expect(catatRect.top, greaterThanOrEqualTo(barRect.top - 1.0));
      expect(catatRect.height, lessThanOrEqualTo(56.0));
      // Diam mentok-bawah: tak ada teks body diiris lingkaran/dock.
      final scrollables = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final st = tester.state<ScrollableState>(scrollables.first);
      st.position.jumpTo(st.position.maxScrollExtent);
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final catat = tester.getRect(find.bySemanticsLabel('Catat transaksi'));
      final covered = <String>[];
      for (final e in find.byType(Text).evaluate()) {
        final t = e.widget as Text;
        final s = t.data ?? '';
        if (s.isEmpty) continue;
        Rect r;
        try {
          r = tester.getRect(find.byWidget(t).first);
        } catch (_) {
          continue;
        }
        if (barRect.contains(r.center)) continue; // label milik dock
        if (r.overlaps(catat) || r.overlaps(barRect)) covered.add(s);
      }
      expect(covered, isEmpty, reason: 'tertutup: $covered');
    } finally {
      await _cleanup(tester, db);
    }
  });
}
