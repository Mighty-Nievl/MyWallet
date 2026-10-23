/// Parse satu kolom jadi nominal + catatan (v1.40.0).
///
/// Kenapa: form Catat punya dua isian (Nominal, Catatan), dan cara tercepat
/// user mencatat adalah mengetik "makan 25 ribu" di catatan. Dulu simpan
/// ditolak "Isi nominal dulu (lebih dari 0)" walau angkanya sudah ada di
/// layar — user harus memindahkan angkanya sendiri ke kolom nominal.
///
/// Murni string → angka (tanpa widget, tanpa DB), jadi seluruh aturan di
/// bawah bisa diuji tanpa memompa layar.
///
/// Urutan pencarian (yang pertama ketemu menang, teks lain jadi catatan):
/// 1. **ribuan bertitik** — "50.000", "Rp1.500.000";
/// 2. **angka + satuan** — "25 ribu", "15rb", "25k", "1,5jt", "5 juta";
/// 3. **angka polos ≥ 4 digit** — "25000", "350000".
///
/// Angka < 1000 TANPA satuan sengaja ditolak: "beli 3 telur" bukan Rp3,
/// dan menebak di sini lebih berbahaya daripada meminta user mengisi
/// nominal sendiri. Batas atas 1 triliun juga ditolak (salah ketik).
class QuickParse {
  const QuickParse({required this.amount, required this.note});

  /// Nominal rupiah hasil baca.
  final int amount;

  /// Sisa teks setelah nominal dibuang — dipakai sebagai catatan.
  final String note;
}

final _thousands = RegExp(r'\d{1,3}(?:\.\d{3})+');
final _withUnit = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(ribu|ribuan|rb|k|juta|jt)\b',
  caseSensitive: false,
);
final _plain = RegExp(r'\b\d{4,}\b');
final _rpPrefix = RegExp(r'\brp\.?\s*', caseSensitive: false);
final _spaces = RegExp(r'\s+');

/// Batas atas nominal yang masuk akal untuk satu transaksi.
const _maxAmount = 1000000000000; // Rp1 triliun

int _multiplier(String unit) =>
    (unit == 'juta' || unit == 'jt') ? 1000000 : 1000;

/// null = tidak ada nominal yang bisa dibaca dengan yakin.
QuickParse? parseQuickInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  int? amount;
  Match? hit;

  // 1) Ribuan bertitik: "50.000" / "1.500.000" (desimal asli seperti
  //    "1.5jt" tidak cocok di sini karena tiap titik wajib 3 digit).
  final sep = _thousands.firstMatch(text);
  if (sep != null) {
    amount = int.tryParse(sep.group(0)!.replaceAll('.', ''));
    hit = sep;
  }

  // 2) Angka + satuan: "25 ribu", "15rb", "25k", "1,5jt".
  if (amount == null) {
    final u = _withUnit.firstMatch(text);
    if (u != null) {
      final n = double.tryParse(u.group(1)!.replaceAll(',', '.'));
      if (n != null) {
        amount = (n * _multiplier(u.group(2)!.toLowerCase())).round();
        hit = u;
      }
    }
  }

  // 3) Angka polos minimal 4 digit: "25000".
  if (amount == null) {
    final p = _plain.firstMatch(text);
    if (p != null) {
      amount = int.tryParse(p.group(0)!);
      hit = p;
    }
  }

  if (amount == null || amount <= 0 || amount > _maxAmount) return null;
  return QuickParse(amount: amount, note: _cleanNote(text, hit!));
}

/// Buang potongan nominal dari teks, rapikan sisa spasi/tanda baca, dan
/// buang "Rp" yatim yang tertinggal ("Rp50.000 bensin" → "bensin").
String _cleanNote(String text, Match hit) {
  final rest = '${text.substring(0, hit.start)} ${text.substring(hit.end)}';
  return rest
      .replaceAll(_rpPrefix, ' ')
      .replaceAll(_spaces, ' ')
      .replaceAll(RegExp(r'^[\s,.\-–·]+'), '')
      .replaceAll(RegExp(r'[\s,.\-–·]+$'), '')
      .trim();
}
