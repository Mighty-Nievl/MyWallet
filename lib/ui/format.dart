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
