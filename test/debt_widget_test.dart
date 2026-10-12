import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/debt_actions.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/debt_screen.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget test manajer utang-piutang (v1.15) — level UI.
///
/// - DebtScreen: empty state, list + ringkasan, dialog tambah end-to-end.
/// - HomeScreen: kartu ringkas utang-piutang disembunyikan (redesign v1.24).
///
/// Anti-flaky (insiden 9 Okt 2026 — framework noise saat run bareng):
/// INSTRUMEN membuktikan app + stream BENAR (stream emit 2x, `Siti`
/// muncul, snackbar tampil); test merah karena `TextEditingController
/// was used after being disposed` — controller dialog di-dispose di
/// `finally` saat route masih animasi keluar. DIPERBAIKI di app via
/// `_DialogControllers` (dispose saat unmount). Hardening harness di
/// bawah tetap dipertahankan untuk runner lambat (FakeAsync + isolate
/// SQLite dingin):
///  1. WARM-UP isolate di [_newDb] (`SELECT 1` via runAsync SEBELUM
///     pumpWidget). Isolate fresh + contention = query pertama lambat;
///     tanpa ini, emisi pertama stream telat dan antrean asyncMap
///     menumpuk (save ikut antre di belakang query dingin).
///  2. GATE emisi pertama: tiap test menunggu konten awal (empty state /
///     nama pre-seed) via [_waitFor] SEBELUM interaksi. Dulu test-3
///     langsung buka dialog + save saat stream awal belum emit → tap
///     save antre → timeout 200 ticks fake (<1 dtk wall) → throw di
///     tengah → tree + dialog + field fokus dibuang abrupt oleh test
///     berikut → `_dependents.isEmpty` / `renderObject.child == child`
///     → cascade 4 gagal beruntun.
///  3. [_waitFor] diselingi jeda WALL-CLOCK (runAsync 150ms/10 ticks):
///     notifikasi tabel Drift round-trip via background isolate (waktu
///     dinding nyata); pump fake cepat saja TIDAK cukup.
///  4. try/finally + [_cleanup] (unfocus → tutup dialog via Batal →
///     drain → unmount) + TUTUP DB eksplisit di dalam test (bukan
///     addTearDown) agar tidak ada straggler isolate antar-test.
///  5. Jangan `pumpAndSettle` — stream watch tak pernah settle.
Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Poll sampai [f] ketemu (max [rounds] putaran ≈ rounds×250ms REAL).
///
/// Real-time dominan (bukan fake pump): notifikasi tabel Drift untuk
/// NativeDatabase round-trip via background isolate (waktu dinding
/// nyata). Fakta insiden 9 Okt 2026: probe mekanismenya 12/12 OK di
/// test BIASA (event loop nyata, 9–130ms), tapi di testWidgets
/// (FakeAsync) 200 fake ticks <1 dtk wall tetap tidak emit saat file
/// jalan bareng. Tiap putaran = pump + cek + jeda nyata 250ms.
Future<bool> _waitFor(WidgetTester tester, Finder f, {int rounds = 40}) async {
  for (var i = 0; i < rounds; i++) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return true;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.pump(const Duration(milliseconds: 50));
  return f.evaluate().isNotEmpty;
}

/// Napas wall-clock murni (tanpa fake pump) — untuk stabilisasi isolate.
Future<void> _nap(WidgetTester tester, {int ms = 300}) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    // Warm-up: paksa spawn + open isolate SEBELUM UI subscribe.
    await d.customSelect('SELECT 1').get();
    await d.backfillAccounts(); // seed Utama (v1.25)
    return d;
  });
  return db!;
}

/// Id dompet Utama (di-seed _newDb). Helper agar insertDebt v1.25
/// (wajib accountId) tetap ringkas di tiap test.
Future<int> _utama(AppDatabase db) async => (await db.select(db.accounts).get())
    .firstWhere((a) => a.name == 'Utama')
    .id;

Future<void> _pumpDebt(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const DebtScreen()),
    ),
  );
  await _pump(tester, ticks: 10);
}

/// Bersih-bersih anti-cascade (lihat catatan (4) di atas).
/// TIDAK boleh throw — finally harus selalu lolos.
Future<void> _cleanup(WidgetTester tester, AppDatabase db) async {
  try {
    // Lepas fokus DULU — TextField terfokus yang dibuang abrupt =
    // `_dependents.isEmpty` di test berikutnya.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    final batal = find.text('Batal');
    if (batal.evaluate().isNotEmpty) {
      await tester.tap(batal.first, warnIfMissed: false);
      await _pump(tester, ticks: 10);
    }
  } catch (_) {
    // Abaikan — tujuan cleanup cuma merapikan tree.
  }
  try {
    // Serap emit stream tertunda selagi scope masih hidup.
    await _pump(tester, ticks: 20);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    // Tutup DB eksplisit di sini (bukan teardown): tidak ada
    // straggler isolate yang bocor ke test berikutnya.
    await tester.runAsync(() => db.close());
  } catch (_) {
    // finally tidak boleh throw — apa pun kondisi tree.
  }
}

void main() {
  testWidgets('kosong → empty state + tombol catat', (tester) async {
    final db = await _newDb(tester);
    try {
      await _pumpDebt(tester, db);

      // Gate emisi pertama (DB kosong → empty state).
      expect(
        await _waitFor(
          tester,
          find.text('Belum ada utang / piutang'),
          rounds: 40,
        ),
        isTrue,
      );
      expect(find.text('Catat utang'), findsOneWidget);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('ada utang → ringkasan + item + progress', (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.runAsync(() async {
        final utama = await _utama(db);
        final id = await insertDebt(
          db,
          accountId: utama,
          name: 'Budi',
          isDebt: true,
          total: 1000000,
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 11, 1),
          note: '',
        );
        await insertDebtPayment(
          db,
          debtId: id,
          amount: 250000,
          date: DateTime(2026, 10, 5),
          note: '',
        );
      });
      await _pumpDebt(tester, db);

      // Gate emisi pertama (pre-seed → nama + sisa muncul).
      expect(await _waitFor(tester, find.text('Budi'), rounds: 40), isTrue);
      expect(find.text('Ringkasan utang-piutang'), findsOneWidget);
      // Sisa 750rb tampil di item (format display default: Rp750.000).
      expect(find.textContaining('750.000'), findsWidgets);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('dialog tambah end-to-end → muncul di list + saldo', (
    tester,
  ) async {
    final db = await _newDb(tester);
    try {
      await _pumpDebt(tester, db);

      // Gate emisi pertama DULU (stream hangat) baru interaksi.
      expect(
        await _waitFor(
          tester,
          find.text('Belum ada utang / piutang'),
          rounds: 40,
        ),
        isTrue,
        reason: 'stream awal harus emit sebelum dialog dibuka',
      );

      // Buka dialog via tombol + header.
      await tester.tap(find.byTooltip('Catat utang / piutang').first);
      expect(
        await _waitFor(tester, find.text('Catat utang / piutang'), rounds: 12),
        isTrue,
        reason: 'dialog catat harus terbuka',
      );
      // Urutan TextField dialog: 0=nama, 1=total, 2=catatan.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'Siti');
      await tester.enterText(fields.at(1), '500000');
      await _pump(tester, ticks: 4);
      // Simpan.
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await _pump(tester, ticks: 15);

      // Lapis 1 — DB: submit/addDebt harus masuk walau stream lambat.
      // runAsync return nullable (T?) — fallback [] bila null.
      final inDb = await tester.runAsync(() => fetchDebts(db)) ?? const [];
      expect(
        inDb.any((e) => e.debt.name == 'Siti'),
        isTrue,
        reason: 'save dialog harus masuk DB (submit/addDebt gagal?)',
      );
      // Lapis 2 — UI: stream debtsProvider harus emit ke list.
      expect(
        await _waitFor(tester, find.text('Siti'), rounds: 120),
        isTrue,
        reason: 'stream debtsProvider harus emit ke list',
      );
      expect(find.textContaining('tercatat'), findsOneWidget);
      // Segmen default = Utang → saldo +500rb. Verifikasi via DB langsung.
      final saldo = await tester.runAsync(() => db.getBalance());
      expect(saldo, 500000);
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets('validasi dialog: kosong → error inline, tidak tersimpan', (
    tester,
  ) async {
    final db = await _newDb(tester);
    try {
      await _pumpDebt(tester, db);

      // Gate emisi pertama dulu (stream hangat).
      expect(
        await _waitFor(
          tester,
          find.text('Belum ada utang / piutang'),
          rounds: 40,
        ),
        isTrue,
      );

      await tester.tap(find.byTooltip('Catat utang / piutang').first);
      expect(
        await _waitFor(tester, find.text('Catat utang / piutang'), rounds: 12),
        isTrue,
        reason: 'dialog catat harus terbuka',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));

      expect(
        await _waitFor(tester, find.text('Isi nama dulu.'), rounds: 12),
        isTrue,
      );
      expect(find.text('Isi total lebih dari 0.'), findsOneWidget);
      final debts = await tester.runAsync(() => fetchDebts(db)) ?? const [];
      expect(debts, isEmpty);
      // Dialog SENGAJA dibiarkan terbuka (assert error) — _cleanup
      // di finally yang menutup via Batal.
    } finally {
      await _cleanup(tester, db);
    }
  });

  testWidgets(
    'kartu Beranda tetap tersembunyi meski ada utang (redesign v1.24)',
    (tester) async {
      final db = await _newDb(tester);
      try {
        await tester.runAsync(() async {
          final utama = await _utama(db);
          await insertDebt(
            db,
            accountId: utama,
            name: 'Budi',
            isDebt: true,
            total: 1000000,
            date: DateTime(2026, 10, 1),
            dueDate: null,
            note: '',
          );
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

        await _pump(tester, ticks: 30);
        await _nap(tester, ms: 300);
        await _pump(tester, ticks: 30);
        expect(find.text('Utang & piutang'), findsNothing);
      } finally {
        await _cleanup(tester, db);
      }
    },
  );

  testWidgets('kartu Beranda sembunyi bila tidak ada utang', (tester) async {
    final db = await _newDb(tester);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: HomeScreen(onGoTab: (_) {}),
          ),
        ),
      );
      // Beri napas wall-clock agar stream awal sempat resolve, lalu
      // assert absence (kosong = hidden baik saat loading maupun data).
      await _pump(tester, ticks: 30);
      await _nap(tester, ms: 300);
      await _pump(tester, ticks: 30);

      expect(find.text('Utang & piutang'), findsNothing);
    } finally {
      await _cleanup(tester, db);
    }
  });
}
