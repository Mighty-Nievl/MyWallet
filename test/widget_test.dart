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
    test('kosong', () => expect(parseRp(''), 0));
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
