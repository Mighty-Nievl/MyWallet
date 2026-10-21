/// Model periode analitik (v1.35.0).
///
/// Sebelumnya seluruh angka di aplikasi dipaku ke BULAN: `selectedMonthProvider`
/// (`'yyyy-MM'`) → `monthRangeProvider` → totals/kategori/grafik. Model ini
/// memisahkan "periode" dari "bulan" supaya Harian/Mingguan/Tahunan bisa
/// memakai jalur query yang sama tanpa menduplikasi rumus tanggal.
///
/// Aturan yang dikunci di sini (dan diuji di `test/period_test.dart`):
/// - Pekan mulai SENIN (kebiasaan Indonesia, bukan ISO minggu-1 yang bisa
///   jatuh di Desember).
/// - `endExclusive` selalu awal unit berikutnya, `endInclusive` = minus 1 ms —
///   pola yang sama dengan `monthRangeOf` supaya query Drift tak berubah.
/// - Semua aritmetika lewat konstruktor `DateTime(y, m, d ± n)`, BUKAN
///   `add(Duration(days:))`, agar tidak meleset satu jam di zona ber-DST
///   (WIB tidak, tapi user bisa di mana saja).
library;

enum PeriodKind { harian, mingguan, bulanan, tahunan }

class Period {
  const Period._(this.kind, this.start);

  /// Normalisasi: [anchor] boleh tanggal apa saja, hasilnya selalu awal unit.
  factory Period.of(PeriodKind kind, DateTime anchor) =>
      Period._(kind, startOf(kind, anchor));

  final PeriodKind kind;

  /// Awal periode (00:00 waktu lokal).
  final DateTime start;

  static DateTime startOf(PeriodKind kind, DateTime d) {
    switch (kind) {
      case PeriodKind.harian:
        return DateTime(d.year, d.month, d.day);
      case PeriodKind.mingguan:
        // weekday: Senin=1 … Minggu=7.
        return DateTime(d.year, d.month, d.day - (d.weekday - 1));
      case PeriodKind.bulanan:
        return DateTime(d.year, d.month, 1);
      case PeriodKind.tahunan:
        return DateTime(d.year, 1, 1);
    }
  }

  DateTime get endExclusive {
    switch (kind) {
      case PeriodKind.harian:
        return DateTime(start.year, start.month, start.day + 1);
      case PeriodKind.mingguan:
        return DateTime(start.year, start.month, start.day + 7);
      case PeriodKind.bulanan:
        return DateTime(start.year, start.month + 1, 1);
      case PeriodKind.tahunan:
        return DateTime(start.year + 1, 1, 1);
    }
  }

  /// Batas akhir INKLUSIF untuk query `between` di Drift.
  DateTime get endInclusive =>
      endExclusive.subtract(const Duration(milliseconds: 1));

  /// Rentang siap pakai untuk query — bentuk yang sama dengan `monthRangeOf`.
  (DateTime, DateTime) get range => (start, endInclusive);

  /// Geser sejumlah unit periode (boleh negatif).
  Period shift(int delta) {
    switch (kind) {
      case PeriodKind.harian:
        return Period._(kind, DateTime(start.year, start.month, start.day + delta));
      case PeriodKind.mingguan:
        return Period._(
          kind,
          DateTime(start.year, start.month, start.day + delta * 7),
        );
      case PeriodKind.bulanan:
        return Period._(kind, DateTime(start.year, start.month + delta, 1));
      case PeriodKind.tahunan:
        return Period._(kind, DateTime(start.year + delta, 1, 1));
    }
  }

  Period get previous => shift(-1);

  /// true bila [now] (default: hari ini) jatuh di dalam periode ini.
  /// Dipakai untuk memilih kata "ini" vs tanggal eksplisit di label.
  bool containsToday({DateTime? now}) {
    final n = now ?? DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return !d.isBefore(DateTime(start.year, start.month, start.day)) &&
        d.isBefore(endExclusive);
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);

  @override
  String toString() => 'Period(${kind.name}, ${start.toIso8601String()})';
}
