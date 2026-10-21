// Test v1.35.0 — model periode (harian/mingguan/bulanan/tahunan).
//
// Semua tanggal di sini EKSPLISIT (bukan DateTime.now()) supaya hasilnya
// deterministik dan tidak berubah tergantung hari test dijalankan.
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/period.dart';

void main() {
  group('harian', () {
    test('rentang = 00:00 s/d 23:59:59.999 hari itu', () {
      final p = Period.of(PeriodKind.harian, DateTime(2026, 10, 21, 15, 30));
      expect(p.start, DateTime(2026, 10, 21));
      expect(p.endInclusive, DateTime(2026, 10, 21, 23, 59, 59, 999));
      expect(p.endExclusive, DateTime(2026, 10, 22));
    });

    test('geser melewati akhir bulan', () {
      final p = Period.of(PeriodKind.harian, DateTime(2026, 10, 31));
      expect(p.shift(1).start, DateTime(2026, 11, 1));
      expect(p.previous.start, DateTime(2026, 10, 30));
    });

    test('29 Feb tahun kabisat', () {
      final p = Period.of(PeriodKind.harian, DateTime(2028, 2, 28));
      expect(p.shift(1).start, DateTime(2028, 2, 29));
      expect(p.shift(2).start, DateTime(2028, 3, 1));
    });
  });

  group('mingguan', () {
    test('mulai SENIN walau anchor hari Rabu', () {
      // 21 Okt 2026 = Rabu.
      final p = Period.of(PeriodKind.mingguan, DateTime(2026, 10, 21));
      expect(p.start, DateTime(2026, 10, 19)); // Senin
      expect(p.endExclusive, DateTime(2026, 10, 26));
      expect(p.endInclusive, DateTime(2026, 10, 25, 23, 59, 59, 999));
    });

    test('anchor hari Minggu masuk pekan yang mulai Senin sebelumnya', () {
      // 1 Nov 2026 = Minggu.
      final p = Period.of(PeriodKind.mingguan, DateTime(2026, 11, 1));
      expect(p.start, DateTime(2026, 10, 26));
    });

    test('geser 7 hari, termasuk lintas tahun', () {
      final p = Period.of(PeriodKind.mingguan, DateTime(2026, 12, 30));
      expect(p.shift(1).start, DateTime(2027, 1, 4));
      expect(p.shift(-1).start, DateTime(2026, 12, 21));
    });
  });

  group('bulanan', () {
    test('Oktober 2026', () {
      final p = Period.of(PeriodKind.bulanan, DateTime(2026, 10, 21));
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.endInclusive, DateTime(2026, 10, 31, 23, 59, 59, 999));
    });

    test('Februari tahun kabisat = 29 hari', () {
      final p = Period.of(PeriodKind.bulanan, DateTime(2028, 2, 10));
      expect(p.endExclusive, DateTime(2028, 3, 1));
      expect(p.endInclusive.day, 29);
    });

    test('Januari mundur ke Desember tahun lalu', () {
      final p = Period.of(PeriodKind.bulanan, DateTime(2026, 1, 5));
      expect(p.previous.start, DateTime(2025, 12, 1));
      expect(p.previous.endInclusive, DateTime(2025, 12, 31, 23, 59, 59, 999));
    });
  });

  group('tahunan', () {
    test('rentang setahun penuh', () {
      final p = Period.of(PeriodKind.tahunan, DateTime(2026, 7, 4));
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.endExclusive, DateTime(2027, 1, 1));
      expect(p.endInclusive, DateTime(2026, 12, 31, 23, 59, 59, 999));
    });

    test('geser lintas tahun', () {
      final p = Period.of(PeriodKind.tahunan, DateTime(2026, 7, 4));
      expect(p.shift(-1).start, DateTime(2025, 1, 1));
      expect(p.shift(2).start, DateTime(2028, 1, 1));
    });
  });

  group('containsToday', () {
    test('harian: hanya hari yang sama', () {
      final p = Period.of(PeriodKind.harian, DateTime(2026, 10, 21));
      expect(p.containsToday(now: DateTime(2026, 10, 21, 23, 59)), isTrue);
      expect(p.containsToday(now: DateTime(2026, 10, 22, 0, 1)), isFalse);
    });

    test('bulanan: awal & akhir bulan inklusif', () {
      final p = Period.of(PeriodKind.bulanan, DateTime(2026, 10, 15));
      expect(p.containsToday(now: DateTime(2026, 10, 1)), isTrue);
      expect(p.containsToday(now: DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(p.containsToday(now: DateTime(2026, 11, 1)), isFalse);
    });

    test('tahunan: 31 Des inklusif, 1 Jan tahun depan tidak', () {
      final p = Period.of(PeriodKind.tahunan, DateTime(2026, 3, 3));
      expect(p.containsToday(now: DateTime(2026, 12, 31, 22)), isTrue);
      expect(p.containsToday(now: DateTime(2027, 1, 1)), isFalse);
    });
  });

  test('kesetaraan: kind sama + start sama = periode sama', () {
    final a = Period.of(PeriodKind.mingguan, DateTime(2026, 10, 21));
    final b = Period.of(PeriodKind.mingguan, DateTime(2026, 10, 23));
    final c = Period.of(PeriodKind.bulanan, DateTime(2026, 10, 21));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('range() konsisten dengan monthRangeOf untuk bulanan', () {
    // Pola yang sama dengan monthRangeOf: awal bulan s/d 23:59:59.999.
    final p = Period.of(PeriodKind.bulanan, DateTime(2026, 10, 21));
    expect(p.range.$1, DateTime(2026, 10, 1));
    expect(p.range.$2, DateTime(2026, 10, 31, 23, 59, 59, 999));
  });
}
