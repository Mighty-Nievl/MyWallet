// Kontrak spacing Beranda (v1.42.0) — mengunci "satu rail + satu ritme".
//
// Kenapa test ini ada: audit 14 Okt menemukan EMPAT tepi teks di satu
// layar (x16 judul, x28 baris transaksi, x32 kartu arus kas, x40 hero).
// Mata tak menghitung 12 vs 16, tapi kolom kiri yang bergoyang saat
// menggulir terlihat jelas. Angka-angka itu sudah diseragamkan; test ini
// yang mencegahnya kembali (drift sebelumnya lolos karena CI hanya
// membandingkan logika, bukan piksel).
//
// Yang dikunci:
// 1. RAIL — judul section di x=16 (page); SEMUA teks di dalam kartu di
//    x=32 (page 16 + padding kartu 16). Hero dan baris transaksi ikut.
// 2. RITME — dalam satu blok (hero → periode → arus kas) jarak 24;
//    antar section tetap 32 (sectionGapLarge).
// 3. TOKEN — cardPadding 16 & hero memakai token yang sama (bukan 24).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/components/app_card.dart';
import 'package:mywallet/ui/components/category_glyph.dart';
import 'package:mywallet/ui/components/period_switcher.dart';
import 'package:mywallet/ui/design/app_spacing.dart';
import 'package:mywallet/ui/shell.dart';
import 'package:mywallet/ui/widgets/flow_cards.dart';

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

/// Flush timer Drift (wajib — tanpa ini test pertama gagal dengan
/// "A Timer is still pending": StreamQueryStore.markAsClosed).
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
  test('token spacing: satu rail 16 + ritme 24/32 (v1.42.0)', () {
    // Rail: padding dalam kartu HARUS 16 — bukan 12/24 lagi.
    expect(AppSpacing.cardPadding.left, 16.0);
    expect(AppSpacing.cardPadding.right, 16.0);
    expect(AppSpacing.page, 16.0);
    // Ritme: dalam blok 24, antar section 32.
    expect(AppSpacing.s24, 24.0);
    expect(AppSpacing.sectionGapLarge, 32.0);
  });

  testWidgets('Beranda: teks kartu x=32, judul section x=16 (v1.42.0)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    try {
      late int accountId;
      await tester.runAsync(() async {
        final accounts = await db.select(db.accounts).get();
        accountId = accounts.firstWhere((a) => a.name == 'Utama').id;
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
                  accountId: Value(accountId),
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

      // ── RAIL 1: judul section di x = 16 (di luar kartu) ────────────
      final sectionTitle = find.text('Terakhir dicatat');
      expect(sectionTitle, findsOneWidget);
      expect(
        tester.getRect(sectionTitle).left,
        AppSpacing.page,
        reason: 'judul section harus di rail 16',
      );

      // ── RAIL 2: teks di dalam kartu di x = 32 ─────────────────────
      // Hero dompet: nama dompet = teks pertama di dalam kartu.
      final heroLabel = find.text('Utama');
      expect(heroLabel, findsWidgets);
      expect(
        tester.getRect(heroLabel.first).left,
        AppSpacing.page + AppSpacing.cardPadding.left,
        reason: 'hero harus ikut rail 32 (dulu 24 → x40)',
      );

      // Kartu arus kas: tepi kartu x16, isi kartu inset 16 (padding) —
      // label duduk setelah ikon 26 + gap 8, jadi +50 dari tepi kartu.
      // Kalau padding balik ke 24, angkanya jadi 58 dan test ini merah.
      final flowLabel = find.text('Pemasukan');
      expect(flowLabel, findsOneWidget);
      final flowCard =
          find.ancestor(of: flowLabel, matching: find.byType(Material)).first;
      final flowCardRect = tester.getRect(flowCard);
      expect(
        flowCardRect.left,
        AppSpacing.page,
        reason: 'tepi kartu arus kas = page 16',
      );
      expect(
        tester.getRect(flowLabel).left - flowCardRect.left,
        AppSpacing.cardPadding.left + 26 + AppSpacing.s8,
        reason: 'kartu arus kas harus pakai padding 16, bukan 24',
      );

      // Baris transaksi: kartu mulai x16, isi (glyph) mulai x32.
      final note = find.text('Jajan 0');
      expect(note, findsOneWidget);
      final txCard = find
          .ancestor(of: note, matching: find.byType(AppCard))
          .first;
      expect(
        tester.getRect(txCard).left,
        AppSpacing.page,
        reason: 'tepi kartu transaksi = page 16',
      );
      final glyph = find
          .descendant(of: txCard, matching: find.byType(CategoryGlyph))
          .first;
      expect(
        tester.getRect(glyph).left,
        closeTo(AppSpacing.page + AppSpacing.cardPadding.left, 1.0),
        reason: 'isi baris transaksi harus ikut rail 32 (dulu 12 → x28); '
            'AppCard menambah border 1px sehingga terukur 33',
      );

      // ── RITME: hero → periode = 24, periode → arus kas = 24 ───────
      final heroCard = find.byKey(ValueKey('home:card-$accountId'));
      expect(heroCard, findsOneWidget);
      final heroBottom = tester.getRect(heroCard).bottom;
      final switcherTop = tester.getRect(find.byType(PeriodSwitcher)).top;
      expect(
        switcherTop - heroBottom,
        AppSpacing.s24,
        reason: 'hero → periode harus 24 (dulu 16)',
      );

      final periodBottom = tester.getRect(find.byType(PeriodNav)).bottom;
      final flowTop = tester.getRect(find.byType(FlowCards)).top;
      expect(
        flowTop - periodBottom,
        AppSpacing.s24,
        reason: 'periode → arus kas harus 24 (dulu 12)',
      );
    } finally {
      await _cleanup(tester, db);
    }
  });
}
