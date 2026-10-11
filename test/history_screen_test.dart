import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/components/b2c_chip.dart';
import 'package:mywallet/ui/screens/history_screen.dart';
import 'package:mywallet/ui/widgets/tx_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget test Riwayat (v1.24.8 + v1.24.9) — nutup kritik brutal L1/L3/L4.
///
/// v1.24.8: Semua-reset, strip hasil, grup tanggal.
/// v1.24.9: search kategori+nominal, strip jujur limit, Semua sadar
/// keyword, toggle tipe, debounce, empty bercabang, chip a11y+48px,
/// tile dense arsip.
///
/// Harness ikut pola debt_widget_test: pump manual + _waitFor +
/// try/finally, tanpa pumpAndSettle.
Future<void> _pump(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
  addTearDown(db!.close);
  return db;
}

Future<void> _tx(
  AppDatabase db,
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

Future<void> _pumpHistory(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const HistoryScreen()),
    ),
  );
  await _pump(tester, ticks: 10);
}

Future<void> _flushDb(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('chip Semua reset kategori juga (v1.24.8)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);

      // Aktifkan filter kategori: scroll ke chip lalu ketuk
      // (chip kategori off-screen di horizontal scroll).
      final chip = find.textContaining('Makan & Minum').first;
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await _pump(tester);
      // Ojek (Transportasi) ikut hilang karena filter kategori.
      expect(find.text('Ojek'), findsNothing);

      // Ketuk "Semua" → kategori ikut reset, Ojek muncul lagi.
      final semua = find.text('Semua');
      await tester.ensureVisible(semua);
      await tester.pump();
      await tester.tap(semua);
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Ojek')), isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('strip hasil: count + masuk + keluar (v1.24.8)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 100000, false, 9, today, note: 'Gaji');
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(
        await _waitFor(tester, find.textContaining('3 transaksi')),
        isTrue,
      );
      expect(find.textContaining('Masuk +Rp100.000'), findsOneWidget);
      expect(find.textContaining('Keluar -Rp63.000'), findsOneWidget);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('grup tanggal: header grup + tanpa tanggal per baris (v1.24.8)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 60000, true, 1, yesterday, note: 'Seblak');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Hari ini')), isTrue);
      expect(find.text('Kemarin'), findsOneWidget);
      // Tanggal tidak diulang di subtitle tiap baris.
      expect(find.textContaining('· Hari ini'), findsNothing);
      expect(find.textContaining('· Kemarin'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('search temukan nama kategori tanpa note (v1.24.9)', (
    tester,
  ) async {
    // Kritik L4: dulu cuma note LIKE — tx tanpa note tak bisa ditemukan.
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today); // note kosong
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan & Minum')), isTrue);
      // Ketik nama kategori → tx tanpa-note ikut ketemu.
      await tester.enterText(find.byType(TextField), 'Makan');
      await tester.pump(const Duration(milliseconds: 500));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Makan & Minum')), isTrue);
      expect(find.text('Ojek'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('search temukan nominal (v1.24.9)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 60000, true, 1, today, note: 'Seblak');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Seblak')), isTrue);
      await tester.enterText(find.byType(TextField), '60000');
      await tester.pump(const Duration(milliseconds: 500));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Seblak')), isTrue);
      expect(find.text('Ojek'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('Semua padam saat keyword aktif (v1.24.9)', (tester) async {
    // Kritik L4: dulu Semua tetap menyala walau daftar tersaring keyword.
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      await tester.enterText(find.byType(TextField), 'Makan');
      await tester.pump(const Duration(milliseconds: 500));
      await _pump(tester);
      // Chip Semua TIDAK selected selagi keyword menyaring.
      final semuaChip = tester.widget<B2CFilterChip>(
        find.widgetWithText(B2CFilterChip, 'Semua'),
      );
      expect(semuaChip.selected, isFalse);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('chip tipe bisa toggle-off (v1.24.9)', (tester) async {
    // Kritik L1: dulu tipe terkunci aktif, kategori bisa toggle-off.
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
      await _tx(db, 100000, false, 9, today, note: 'Gaji');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      final chip = find.widgetWithText(B2CFilterChip, 'Pengeluaran');
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await _pump(tester);
      expect(find.text('Gaji'), findsNothing);
      // Ketuk lagi → lepas, Gaji muncul kembali.
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Gaji')), isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('empty bercabang: filter vs bulan kosong (v1.24.9)', (
    tester,
  ) async {
    // Kritik L4: dulu satu state menuduh veteran "catat pertamamu".
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 100000, false, 9, today, note: 'Gaji');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Gaji')), isTrue);
      // Filter sempit → judul "Tidak ada yang cocok", tanpa tuduhan.
      await tester.enterText(find.byType(TextField), 'zzz-tak-ada');
      await tester.pump(const Duration(milliseconds: 500));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Tidak ada yang cocok')), isTrue);
      expect(find.textContaining('Coba longgarkan', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('pertama'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('chip a11y + 48px + tile dense (v1.24.9)', (tester) async {
    // Kritik L1/L2: GestureDetector mentah ~40px → Semantics + 48px;
    // arsip rapat (dense) vs teaser lega.
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      // Semantik tombol ada di tiap chip (Semantics button + label).
      final sem = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Semua'),
              matching: find.byWidgetPredicate((w) => w is Semantics),
            )
            .first,
      );
      expect(sem.label, 'Semua');
      // Tinggi chip ≥ touchMin 48 (constraint minHeight; font test
      // Ahem lebih tinggi dari font asli, jadi assert batas bawah).
      final chipBox = tester.getSize(
        find.widgetWithText(B2CFilterChip, 'Semua').first,
      );
      expect(chipBox.height, greaterThanOrEqualTo(48));
      // Tile arsip dense.
      final tile = tester.widget<TxTile>(find.byType(TxTile).first);
      expect(tile.dense, isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('strip jujur soal limit 100 (v1.24.9, unit DB)', (tester) async {
    // Kritik L4: 105 baris → tampil 100 + "Menampilkan 100 dari 105".
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);
      for (var i = 0; i < 105; i++) {
        await _tx(db, 1000 + i, true, 1, today, note: 'Item $i');
      }
      final shown = await db.watchHistory(from: from, to: to).first;
      final total = await db.watchHistoryCount(from: from, to: to).first;
      expect(shown.length, 100);
      expect(total, 105);
    });
    await _flushDb(tester);
  });
}
