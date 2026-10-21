// Helper format tampilan: rupiah, tanggal, dan kunci bulan "yyyy-MM".

import '../data/period.dart';

String _group(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 1500000 -> "Rp1.500.000" · -5000 -> "-Rp5.000"
String formatRp(int amount) {
  final neg = amount < 0;
  return '${neg ? '-' : ''}Rp${_group(amount.abs())}';
}

/// Format ringkas Indonesia: 25000 -> "Rp25 rb", 1500000 -> "Rp1,5 jt",
/// 2000000000 -> "Rp2 M". Desimal koma, maksimal 1 digit, tanpa ",0".
/// Nilai < 1000 tetap penuh ("Rp500").
String formatRpCompact(int amount) {
  final neg = amount < 0;
  final n = amount.abs();
  String fmt(double v) {
    final rounded = (v * 10).round() / 10;
    var s = rounded.toStringAsFixed(rounded == rounded.roundToDouble() ? 0 : 1);
    s = s.replaceAll('.', ',');
    return s;
  }

  final body = n < 1000
      ? _group(n)
      : n < 1000000
          ? '${fmt(n / 1000)} rb'
          : n < 1000000000
              ? '${fmt(n / 1000000)} jt'
              : '${fmt(n / 1000000000)} M';
  return '${neg ? '-' : ''}Rp$body';
}

/// Tanggal relatif Indonesia: "Hari ini", "Kemarin", "Besok",
/// selebihnya formatDate biasa. [now] untuk testing.
String formatDateRelative(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = day.difference(today).inDays;
  return switch (diff) {
    0 => 'Hari ini',
    -1 => 'Kemarin',
    1 => 'Besok',
    _ => formatDate(d),
  };
}

/// Digit tergrup untuk kolom input nominal (tanpa "Rp"): 1500000 -> "1.500.000".
/// Dipakai sebagai teks awal + hasil formatter saat mengetik.
/// Parse kembali dengan [parseRp] (ambil digit saja).
String formatAmountField(int amount) => _group(amount.abs());

/// "Rp1.500.000" / "25 ribu" (angka saja) -> 1500000 / 25.
/// Mengambil semua digit; teks seperti "25 ribu" jadi 25 (bukan 25000).
int parseRp(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits);
}

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const _fullMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String formatDate(DateTime d) => '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

/// "8 Oktober 2026" — versi bulan panjang tanpa nol di depan, persis
/// tanggal sapaan mockup: "Rabu, 8 Oktober 2026".
String formatDateLong(DateTime d) =>
    '${d.day} ${_fullMonths[d.month - 1]} ${d.year}';

String formatDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatDate(d)} · $hh:$mm';
}

/// "2026-10" -> "Oktober 2026"
String monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final y = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  if (y == 0 || m < 1 || m > 12) return key;
  return '${_fullMonths[m - 1]} $y';
}

/// "2026-10" -> "OKT" — label bulan singkat kapital untuk tile metrik
/// Beranda (mockup ala GoPay: "MASUK OKT" / "KELUAR OKT").
String monthAbbrLabel(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key.toUpperCase();
  final m = int.tryParse(parts[1]) ?? 0;
  if (m < 1 || m > 12) return key.toUpperCase();
  return _shortMonths[m - 1].toUpperCase();
}

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';
String currentMonthKey() => monthKey(DateTime.now());

/// Geser kunci bulan, mis. shiftMonth("2026-01", -1) -> "2025-12".
String shiftMonth(String key, int delta) {
  final parts = key.split('-');
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = int.tryParse(parts[1]) ?? DateTime.now().month;
  final d = DateTime(y, m + delta, 1);
  return monthKey(d);
}

// ── Periode (v1.35.0) ─────────────────────────────────────────────────────
// Label periode hidup di sini (bukan di data/period.dart) supaya model
// tanggal tetap murni dan bebas dari bahasa tampilan.

/// "21 Okt 2026" · "19–25 Okt 2026" · "Oktober 2026" · "2026".
String periodLabel(Period p) {
  switch (p.kind) {
    case PeriodKind.harian:
      return formatDate(p.start);
    case PeriodKind.mingguan:
      final end = p.endInclusive;
      // Lintas bulan: sebut bulan kedua sisi supaya tak ambigu.
      if (p.start.month == end.month) {
        return '${p.start.day}–${end.day} ${_shortMonths[end.month - 1]} ${end.year}';
      }
      return '${p.start.day} ${_shortMonths[p.start.month - 1]} – '
          '${end.day} ${_shortMonths[end.month - 1]} ${end.year}';
    case PeriodKind.bulanan:
      return monthLabel(monthKey(p.start));
    case PeriodKind.tahunan:
      return '${p.start.year}';
  }
}

/// Nama jenis periode untuk chip switcher.
String periodKindLabel(PeriodKind kind) {
  switch (kind) {
    case PeriodKind.harian:
      return 'Harian';
    case PeriodKind.mingguan:
      return 'Mingguan';
    case PeriodKind.bulanan:
      return 'Bulanan';
    case PeriodKind.tahunan:
      return 'Tahunan';
  }
}

/// Frasa pembanding untuk delta kartu arus: "kemarin"/"minggu lalu"/...
/// Dipakai [FlowCards] supaya "▲ 12% dari bulan lalu" tidak bohong saat
/// periode aktif harian/mingguan/tahunan.
String previousPeriodPhrase(PeriodKind kind) {
  switch (kind) {
    case PeriodKind.harian:
      return 'kemarin';
    case PeriodKind.mingguan:
      return 'minggu lalu';
    case PeriodKind.bulanan:
      return 'bulan lalu';
    case PeriodKind.tahunan:
      return 'tahun lalu';
  }
}

/// Frasa judul section: "hari ini"/"minggu ini"/... bila periode berjalan,
/// selain itu label eksplisit (jangan bilang "bulan ini" untuk bulan lalu).
String periodRelativeLabel(Period p) {
  if (!p.containsToday()) return periodLabel(p);
  switch (p.kind) {
    case PeriodKind.harian:
      return 'hari ini';
    case PeriodKind.mingguan:
      return 'minggu ini';
    case PeriodKind.bulanan:
      return 'bulan ini';
    case PeriodKind.tahunan:
      return 'tahun ini';
  }
}
