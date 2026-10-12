import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/receipt_parse.dart';
import 'package:mywallet/data/report_pdf_service.dart';

/// Test parser struk (fungsi murni, tanpa kamera/ML Kit).
void main() {
  group('parseMoneyToken', () {
    test('titik ribuan', () => expect(parseMoneyToken('25.000'), 25000));
    test('dengan Rp', () => expect(parseMoneyToken('Rp 45.000'), 45000));
    test('desimal koma Indonesia', () {
      expect(parseMoneyToken('12.500,00'), 12500);
    });
    test('ribuan Inggris', () => expect(parseMoneyToken('25,000'), 25000));
    test('kosong', () => expect(parseMoneyToken(''), isNull));
    test('bukan angka', () => expect(parseMoneyToken('TERIMA KASIH'), isNull));
  });

  group('parseReceiptText — total', () {
    test('struk Indomaret: ambil TOTAL, abaikan TUNAI/KEMBALI', () {
      const ocr = '''
INDOMARET
Jl. Mawar No. 10
Biskuit Roma  12.500
Teh Botol     5.000
------------------------
TOTAL            Rp 17.500
TUNAI            Rp 20.000
KEMBALI          Rp 2.500
08/10/2026 19:21
TERIMA KASIH
''';
      final d = parseReceiptText(ocr);
      expect(d.amount, 17500);
      expect(d.merchant, 'INDOMARET');
      expect(d.date, DateTime(2026, 10, 8));
      expect(d.suggestedCategory, 'Belanja');
    });

    test('grand total menang atas subtotal', () {
      const ocr = '''
WARTEG BAHARI
Nasi + Ayam  15.000
Es Teh        5.000
SUBTOTAL     20.000
GRAND TOTAL  20.000
TUNAI        50.000
KEMBALI      30.000
''';
      final d = parseReceiptText(ocr);
      expect(d.amount, 20000);
      expect(d.suggestedCategory, 'Makan & Minum');
    });

    test('tanpa label TOTAL: fallback angka terbesar non-tunai', () {
      const ocr = '''
PARKIR MALL
1 jam  10.000
Denda   5.000
''';
      final d = parseReceiptText(ocr);
      expect(d.amount, 10000);
    });

    test('teks kosong → draf kosong (jangan ngarang)', () {
      final d = parseReceiptText('   ');
      expect(d.amount, isNull);
      expect(d.merchant, isNull);
      expect(d.date, isNull);
    });
  });

  group('parseReceiptDate', () {
    test('numerik slash', () {
      expect(parseReceiptDate('08/10/2026'), DateTime(2026, 10, 8));
    });
    test('nama bulan Indonesia', () {
      expect(parseReceiptDate('8 Oktober 2026'), DateTime(2026, 10, 8));
    });
    test('tidak ada tanggal → null', () {
      expect(parseReceiptDate('TOTAL 10.000'), isNull);
    });
  });

  group('suggestCategoryForText', () {
    test('SPBU → Transportasi', () {
      expect(
        suggestCategoryForText('SPBU PERTAMINA\nPertalite 100.000'),
        'Transportasi',
      );
    });
    test('PLN → Tagihan', () {
      expect(suggestCategoryForText('TOKEN LISTRIK PLN 100.000'), 'Tagihan');
    });
    test('apotek → Kesehatan', () {
      expect(suggestCategoryForText('APOTEK K24\nObat 25.000'), 'Kesehatan');
    });
    test('tak dikenal → null', () {
      expect(suggestCategoryForText('XYZ ABC 123'), isNull);
    });
  });

  group('report PDF (db in-memory)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.select(db.categories).get(); // seed bawaan
      await db.backfillAccounts(); // seed Utama (v1.25)
    });

    tearDown(() async {
      await db.close();
    });

    test('fetchMonthReport: total + kategori + transaksi', () async {
      final cats = await db.select(db.categories).get();
      final makan = cats.firstWhere((c) => c.name == 'Makan & Minum');
      final utama = (await db.select(db.accounts).get())
          .firstWhere((a) => a.name == 'Utama')
          .id;
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 25000,
              isExpense: const Value(true),
              categoryId: Value(makan.id),
              date: DateTime(2026, 10, 5),
              note: const Value('warteg'),
              accountId: Value(utama),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 5000000,
              isExpense: const Value(false),
              date: DateTime(2026, 10, 1),
              accountId: Value(utama),
            ),
          );

      final (from, to) = monthRangeOf('2026-10');
      final data = await fetchMonthReport(
        db,
        month: '2026-10',
        from: from,
        to: to,
      );
      expect(data.income, 5000000);
      expect(data.expense, 25000);
      expect(data.net, 5000000 - 25000);
      expect(data.byCategory, hasLength(1));
      expect(data.byCategory.single.name, 'Makan & Minum');
      expect(data.transactions, hasLength(2));
    });

    test('buildMonthReportPdf: header PDF valid + ada isi', () async {
      final (from, to) = monthRangeOf('2026-10');
      final data = await fetchMonthReport(
        db,
        month: '2026-10',
        from: from,
        to: to,
      );
      final bytes = await buildMonthReportPdf(data);
      // Header file PDF: "%PDF-".
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('bulan kosong tetap jadi PDF valid', () async {
      final (from, to) = monthRangeOf('2026-11');
      final data = await fetchMonthReport(
        db,
        month: '2026-11',
        from: from,
        to: to,
      );
      expect(data.transactions, isEmpty);
      final bytes = await buildMonthReportPdf(data);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
