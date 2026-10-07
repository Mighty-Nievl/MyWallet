import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/ui/format.dart';

void main() {
  group('formatRp', () {
    test('nol', () => expect(formatRp(0), 'Rp0'));
    test('ribuan', () => expect(formatRp(25000), 'Rp25.000'));
    test('jutaan', () => expect(formatRp(1500000), 'Rp1.500.000'));
    test('negatif', () => expect(formatRp(-5000), '-Rp5.000'));
  });

  group('parseRp', () {
    test('angka polos', () => expect(parseRp('25000'), 25000));
    test('dengan Rp dan titik', () => expect(parseRp('Rp1.500.000'), 1500000));
    test('dengan titik input', () => expect(parseRp('1.500.000'), 1500000));
    test('kosong', () => expect(parseRp(''), 0));
  });

  group('formatAmountField', () {
    test('nol', () => expect(formatAmountField(0), '0'));
    test('ribuan', () => expect(formatAmountField(25000), '25.000'));
    test('jutaan', () => expect(formatAmountField(1500000), '1.500.000'));
  });

  group('formatRpCompact', () {
    test('di bawah seribu tetap penuh',
        () => expect(formatRpCompact(500), 'Rp500'));
    test('ribuan', () => expect(formatRpCompact(25000), 'Rp25 rb'));
    test('ribuan desimal koma',
        () => expect(formatRpCompact(25500), 'Rp25,5 rb'));
    test('jutaan', () => expect(formatRpCompact(1500000), 'Rp1,5 jt'));
    test('jutaan bulat tanpa koma',
        () => expect(formatRpCompact(25000000), 'Rp25 jt'));
    test('miliar', () => expect(formatRpCompact(2000000000), 'Rp2 M'));
    test('negatif', () => expect(formatRpCompact(-5000), '-Rp5 rb'));
  });

  group('formatDateRelative', () {
    final now = DateTime(2026, 10, 7, 12);
    test('hari ini',
        () => expect(formatDateRelative(DateTime(2026, 10, 7), now: now),
            'Hari ini'));
    test('kemarin',
        () => expect(formatDateRelative(DateTime(2026, 10, 6), now: now),
            'Kemarin'));
    test('besok',
        () => expect(formatDateRelative(DateTime(2026, 10, 8), now: now),
            'Besok'));
    test('lainnya fallback tanggal penuh',
        () => expect(formatDateRelative(DateTime(2026, 10, 1), now: now),
            '1 Okt 2026'));
  });

  group('bulan', () {
    test('monthKey', () => expect(monthKey(DateTime(2026, 3, 15)), '2026-03'));
    test('monthLabel', () => expect(monthLabel('2026-10'), 'Oktober 2026'));
    test('shiftMonth mundur lewati tahun',
        () => expect(shiftMonth('2026-01', -1), '2025-12'));
    test('shiftMonth maju', () => expect(shiftMonth('2026-10', 2), '2026-12'));
    test('formatDate', () => expect(formatDate(DateTime(2026, 8, 17)), '17 Agu 2026'));
  });
}
