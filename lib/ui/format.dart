// Helper format tampilan: rupiah, tanggal, dan kunci bulan "yyyy-MM".

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
