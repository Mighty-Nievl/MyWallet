// v1.40.0 — "makan 25 ribu": aturan baca nominal dari satu kolom.
//
// Yang dikunci di sini bukan format rupiah (itu `amount_input`), tapi
// kapan kita BERANI menebak nominal dari teks bebas. Salah tebak di sini
// = transaksi tercatat dengan nominal yang tidak pernah diketik user,
// jadi kasus ragu harus menghasilkan null, bukan angka.
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/quick_parse.dart';

void main() {
  group('parseQuickInput — satuan', () {
    test('"makan 25 ribu" → 25000, catatan "makan"', () {
      final q = parseQuickInput('makan 25 ribu')!;
      expect(q.amount, 25000);
      expect(q.note, 'makan');
    });

    test('"kopi 15rb" → 15000', () {
      expect(parseQuickInput('kopi 15rb')!.amount, 15000);
    });

    test('"parkir 5k" → 5000', () {
      expect(parseQuickInput('parkir 5k')!.amount, 5000);
    });

    test('"gaji 5 juta" → 5000000', () {
      final q = parseQuickInput('gaji 5 juta')!;
      expect(q.amount, 5000000);
      expect(q.note, 'gaji');
    });

    test('"makan siang 1,5jt" → 1500000 + catatan utuh', () {
      final q = parseQuickInput('makan siang 1,5jt')!;
      expect(q.amount, 1500000);
      expect(q.note, 'makan siang');
    });

    test('"bayar 2.5 juta" → 2500000 (titik desimal di depan satuan)', () {
      expect(parseQuickInput('bayar 2.5 juta')!.amount, 2500000);
    });
  });

  group('parseQuickInput — ribuan bertitik & angka polos', () {
    test('"bensin 50.000" → 50000', () {
      final q = parseQuickInput('bensin 50.000')!;
      expect(q.amount, 50000);
      expect(q.note, 'bensin');
    });

    test('"Rp1.500.000 gaji" → 1500000, "Rp" yatim dibuang', () {
      final q = parseQuickInput('Rp1.500.000 gaji')!;
      expect(q.amount, 1500000);
      expect(q.note, 'gaji');
    });

    test('"jajan 25000" → 25000', () {
      expect(parseQuickInput('jajan 25000')!.amount, 25000);
    });

    test('spasi berlebih dirapikan', () {
      final q = parseQuickInput('makan   25   ribu')!;
      expect(q.amount, 25000);
      expect(q.note, 'makan');
    });

    test('nominal saja → catatan kosong', () {
      final q = parseQuickInput('25.000')!;
      expect(q.amount, 25000);
      expect(q.note, '');
    });
  });

  group('parseQuickInput — harus menolak (null)', () {
    test('tanpa angka', () {
      expect(parseQuickInput('makan'), isNull);
      expect(parseQuickInput(''), isNull);
      expect(parseQuickInput('   '), isNull);
    });

    test('angka kecil tanpa satuan bukan rupiah', () {
      // "beli 3 telur" ≠ Rp3 — lebih baik minta user isi nominal.
      expect(parseQuickInput('beli 3 telur'), isNull);
      expect(parseQuickInput('2 porsi'), isNull);
    });

    test('nol', () {
      expect(parseQuickInput('Rp0'), isNull);
      expect(parseQuickInput('0'), isNull);
    });

    test('salah ketik di atas 1 triliun', () {
      expect(parseQuickInput('999999999999999'), isNull);
      expect(parseQuickInput('9999999999999 triliun'), isNull);
    });
  });
}
