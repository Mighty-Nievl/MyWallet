// ExportService — logika CSV yang dulu menempel di mixin UI tanpa tes.
//
// Yang dikunci: urutan kolom (file lama & baru harus bisa dibuka dengan
// spreadsheet yang sama), pemetaan tipe, dan escaping karakter yang bikin
// CSV rusak (koma, kutip, baris baru di catatan).
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/export_service.dart';

TxWithCategory _tx({
  int amount = 25000,
  bool isExpense = true,
  String? catName = 'Makan',
  String note = 'makan siang',
  DateTime? date,
}) {
  return TxWithCategory(
    id: 1,
    amount: amount,
    isExpense: isExpense,
    categoryId: 1,
    date: date ?? DateTime(2026, 10, 29, 12, 30),
    note: note,
    catName: catName,
  );
}

List<List<dynamic>> _parse(String csv) => Csv(autoDetect: false).decode(csv);

void main() {
  test('header tetap 5 kolom dengan urutan lama', () {
    final rows = _parse(ExportService.buildTransactionsCsv([_tx()]));
    expect(rows.first, ['tanggal', 'tipe', 'kategori', 'nominal', 'catatan']);
  });

  test('pengeluaran → keluar, pemasukan → masuk', () {
    final rows = _parse(
      ExportService.buildTransactionsCsv([
        _tx(isExpense: true),
        _tx(isExpense: false, catName: 'Gaji', note: 'gaji'),
      ]),
    );
    expect(rows[1][1], 'keluar');
    expect(rows[2][1], 'masuk');
  });

  test('kategori null jadi kosong, nominal angka apa adanya', () {
    final rows = _parse(
      ExportService.buildTransactionsCsv([_tx(catName: null, amount: 1500000)]),
    );
    expect(rows[1][2], '');
    expect(rows[1][3], '1500000');
  });

  test('tanggal ISO 8601 (bisa diurutkan spreadsheet)', () {
    final rows = _parse(
      ExportService.buildTransactionsCsv([
        _tx(date: DateTime(2026, 1, 5, 8, 5)),
      ]),
    );
    expect(rows[1][0], startsWith('2026-01-05T08:05'));
  });

  test('catatan berkoma & berbaris baru tidak merusak kolom', () {
    final csv = ExportService.buildTransactionsCsv([
      _tx(note: 'kopi, roti\ndan susu'),
    ]);
    final rows = _parse(csv);
    expect(rows, hasLength(2), reason: 'baris baru di catatan harus dikutip');
    expect(rows[1], hasLength(5));
    expect(rows[1][4], 'kopi, roti\ndan susu');
  });

  test('catatan berisi tanda kutip tetap satu sel', () {
    final rows = _parse(
      ExportService.buildTransactionsCsv([_tx(note: 'bilang "halo"')]),
    );
    expect(rows[1], hasLength(5));
    expect(rows[1][4], 'bilang "halo"');
  });

  test('daftar kosong tetap menghasilkan header saja', () {
    final rows = _parse(ExportService.buildTransactionsCsv([]));
    expect(rows, hasLength(1));
  });
}
