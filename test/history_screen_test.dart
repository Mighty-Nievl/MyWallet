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

/// Widget test Riwayat (v1.24.8 + v1.24.9 + v1.24.10).
///
/// v1.24.8: reset filter, strip hasil, grup tanggal.
/// v1.24.9: search kategori+nominal, strip jujur limit, toggle tipe,
/// debounce, empty bercabang, chip a11y+48px, tile dense arsip.
/// v1.24.10: tile dua-baris (catatan atas, meta+nominal bawah);
/// filter Opsi A — tombol + bottom-sheet ganti chip scroll.
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
    await d.backfillAccounts(); // seed Utama (v1.25)
    return d;
  });
  addTearDown(db!.close);
  return db;
}

/// Id dompet Utama (di-seed _newDb) — v1.25: helper tx WAJIB isi ini.
Future<int> _utama(AppDatabase db) async => (await db.select(db.accounts).get())
    .firstWhere((a) => a.name == 'Utama')
    .id;

Future<void> _tx(
  AppDatabase db,
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
  // v1.24.10 Opsi A: chip scroll horizontal SUDAH tidak ada —
  // filter hidup di tombol + bottom-sheet. Absence-test ini kunci
  // kontraknya (keberadaan satu chip scroll = regresi desain).
  testWidgets('tanpa chip scroll: filter via tombol + sheet (v1.24.10)', (
    tester,
  ) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      expect(find.widgetWithText(B2CFilterChip, 'Semua'), findsNothing);
      expect(find.widgetWithText(B2CFilterChip, 'Pengeluaran'), findsNothing);
      expect(find.widgetWithText(B2CFilterChip, 'Pemasukan'), findsNothing);
      // Tombol filter ada (semantik, tanpa badge saat nol aktif).
      expect(find.byTooltip('Filter, ketuk untuk ubah'), findsNothing);
      expect(
        find.text('Filter, ketuk untuk ubah', findRichText: true),
        findsNothing,
      );
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('sheet filter: kategori + reset (v1.24.10)', (tester) async {
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

      // Buka sheet via tombol filter (semantik eksplisit).
      final btn = find.bySemanticsLabel('Filter, ketuk untuk ubah');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      expect(find.text('Tipe'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);

      // Pilih kategori Makan & Minum → Ojek hilang, badge tombol = 1.
      // .last di ensureVisible juga (teks ganda: tile + sheet row).
      await tester.ensureVisible(find.text('Makan & Minum').last);
      await tester.pump();
      await tester.tap(find.text('Makan & Minum').last);
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      expect(find.text('Ojek'), findsNothing);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      expect(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
        findsOneWidget,
      );

      // Buka lagi → Reset → Ojek muncul kembali.
      await tester.tap(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
      );
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Ojek')), isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('sheet filter: toggle tipe Keluar (v1.24.10)', (tester) async {
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
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      // Chip Keluar di sheet (scope sheet, bukan layar).
      final keluar = find.widgetWithText(B2CFilterChip, 'Keluar');
      expect(keluar, findsOneWidget);
      await tester.tap(keluar);
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      expect(find.text('Gaji'), findsNothing);
      // Toggle-off lagi → Gaji kembali.
      await tester.tap(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
      );
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Gaji')), isTrue);
    } finally {
      await _flushDb(tester);
    }
  });

  testWidgets('tile dua-baris: nominal sejajar + meta ellipsis (v1.24.10)', (
    tester,
  ) async {
    // Layout request user: catatan full-width atas; meta kiri +
    // nominal kanan bawah. Tepi kanan nominal tetap sejajar (v1.24.5).
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang enak sekali');
      await _tx(db, 18000, true, 2, today, note: 'Ojek');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Ojek')), isTrue);
      final r45 = tester.getRect(find.text('-Rp45.000'));
      final r18 = tester.getRect(find.text('-Rp18.000'));
      expect((r45.right - r18.right).abs(), lessThan(1.0));
      // Meta (kategori) di bawah judul, bukan di baris judul.
      final titleRect = tester.getRect(find.text('Makan siang enak sekali'));
      final metaRect = tester.getRect(find.text('Makan & Minum').first);
      expect(metaRect.top, greaterThan(titleRect.bottom));
    } finally {
      await _flushDb(tester);
    }
  });

  // v1.24.10: chip layar → sheet. Alur: tombol → sheet → pilih
  // kategori → Terapkan → Reset via sheet.
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

      // v1.24.10: filter kategori via sheet (chip layar sudah tiada).
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      // .last juga (teks ganda: tile + sheet row).
      await tester.ensureVisible(find.text('Makan & Minum').last);
      await tester.pump();
      await tester.tap(find.text('Makan & Minum').last);
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      // Ojek (Transportasi) ikut hilang karena filter kategori.
      expect(find.text('Ojek'), findsNothing);

      // Reset via sheet → kategori ikut reset, Ojek muncul lagi.
      await tester.tap(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
      );
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
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

  // v1.24.10: "Semua" kini baris sheet seksi Tipe. Keyword aktif
  // TIDAK mengubah selected-nya (keyword bukan dimensi sheet —
  // badge tombol juga tidak menghitungnya): yang diassert = sheet
  // tetap tawarkan Semua-sebagai-tipe + keyword tetap menyaring.
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
      // Keyword tetap menyaring daftar (Ojek hilang).
      expect(find.text('Ojek'), findsNothing);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      // Badge tombol TIDAK menghitung keyword (nol dimensi aktif).
      expect(find.bySemanticsLabel('Filter, ketuk untuk ubah'), findsOneWidget);
    } finally {
      await _flushDb(tester);
    }
  });

  // v1.24.10: toggle tipe via sheet (chip layar sudah tiada).
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
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      expect(find.text('Gaji'), findsNothing);
      // Ketuk lagi → lepas, Gaji muncul kembali.
      await tester.tap(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
      );
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(B2CFilterChip, 'Keluar'));
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
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
      expect(
        find.textContaining('Coba longgarkan', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('pertama'), findsNothing);
    } finally {
      await _flushDb(tester);
    }
  });

  // v1.24.10: tombol filter + badge (chip layar sudah tiada —
  // yang diassert semantik tombol + tile tetap dense).
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
      // Tombol filter bersemantik eksplisit (nol aktif).
      expect(find.bySemanticsLabel('Filter, ketuk untuk ubah'), findsOneWidget);
      // Tinggi tombol ≥ touchMin 48.
      final btnBox = tester.getSize(
        find.bySemanticsLabel('Filter, ketuk untuk ubah').first,
      );
      expect(btnBox.height, greaterThanOrEqualTo(48));
      // Chip sheet tetap a11y (Semantics + 48px) — buka sheet dulu.
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
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

  // v1.25: seksi Dompet di sheet — pilih dompet = list menyempit +
  // badge tombol 1; Reset nol-kan dompet (kembali Semua).
  testWidgets('sheet filter: dompet + badge + reset (v1.25)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final keluargaId = await tester.runAsync(() async {
      final k = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));
      final utama = await _utama(db);
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 45000,
              isExpense: Value(true),
              categoryId: Value(1),
              date: today,
              note: Value('Makan siang'),
              accountId: Value(utama),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 20000,
              isExpense: Value(true),
              categoryId: Value(2),
              date: today,
              note: Value('Jajan anak'),
              accountId: Value(k),
            ),
          );
      return k;
    });
    expect(keluargaId, isNotNull);
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      expect(find.text('Jajan anak'), findsOneWidget);

      // Buka sheet → seksi Dompet ada (2 dompet).
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Keluarga'), findsOneWidget);

      // Pilih Keluarga → Jajan anak saja, badge 1.
      await tester.ensureVisible(find.text('Keluarga').last);
      await tester.pump();
      await tester.tap(find.text('Keluarga').last);
      await _pump(tester);
      await tester.ensureVisible(find.text('Terapkan filter'));
      await tester.pump();
      await tester.tap(find.text('Terapkan filter'));
      await _pump(tester);
      expect(find.text('Makan siang'), findsNothing);
      expect(await _waitFor(tester, find.text('Jajan anak')), isTrue);
      expect(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
        findsOneWidget,
      );

      // Buka lagi → Reset → dompet kembali Semua, badge hilang.
      await tester.tap(
        find.bySemanticsLabel('Filter aktif 1, ketuk untuk ubah'),
      );
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      await tester.ensureVisible(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      expect(find.text('Jajan anak'), findsOneWidget);
      expect(find.bySemanticsLabel('Filter, ketuk untuk ubah'), findsOneWidget);
    } finally {
      await _flushDb(tester);
    }
  });

  // v1.25: 1 dompet = seksi Dompet tampilkan teks info (bukan chip).
  testWidgets('sheet filter: 1 dompet tanpa chip (v1.25)', (tester) async {
    final db = await _newDb(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await _tx(db, 45000, true, 1, today, note: 'Makan siang');
    });
    try {
      await _pumpHistory(tester, db);
      expect(await _waitFor(tester, find.text('Makan siang')), isTrue);
      await tester.tap(find.bySemanticsLabel('Filter, ketuk untuk ubah'));
      await _pump(tester);
      expect(await _waitFor(tester, find.text('Filter riwayat')), isTrue);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.textContaining('Satu dompet'), findsOneWidget);
    } finally {
      await _flushDb(tester);
    }
  });
}
