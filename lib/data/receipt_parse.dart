/// Parser teks struk belanja → draf transaksi.
///
/// Fungsi murni (tanpa Flutter/ML Kit) agar gampang di-test:
/// input = teks mentah hasil OCR, output = [ReceiptDraft].
///
/// Dipakai oleh alur scan struk di form catat:
/// `image_picker` → `google_mlkit_text_recognition` → teks →
/// [parseReceiptText] → prefill form (user tetap koreksi manual).
library;

/// Hasil tebakan dari teks struk. Semua field nullable — kalau tidak
/// ketemu, form tidak diisi (jangan ngarang nominal).
class ReceiptDraft {
  const ReceiptDraft({
    this.amount,
    this.date,
    this.merchant,
    this.note,
    this.suggestedCategory,
  });

  /// Nominal total belanja (rupiah, bilangan bulat). null = tidak ketemu.
  final int? amount;

  /// Tanggal di struk. null = pakai hari ini.
  final DateTime? date;

  /// Nama warung/toko (baris pertama yang masuk akal). null = tidak ketemu.
  final String? merchant;

  /// Saran isi kolom catatan (mis. "Indomaret — scan struk").
  final String? note;

  /// Saran nama kategori (dicocokkan ke nama kategori di DB oleh UI).
  /// Contoh: "Makan & Minum", "Transportasi", "Belanja", ...
  /// null = biar "Tanpa kategori".
  final String? suggestedCategory;
}

/// Parse satu token uang seperti "25.000", "25,000", "12.500,00",
/// "Rp 25.500", "25000" → rupiah int. null bila bukan angka valid.
int? parseMoneyToken(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  // Buang prefix Rp/IDR dan spasi.
  s = s.replaceAll(RegExp(r'\b(rp|idr)\b\.?', caseSensitive: false), '').trim();
  s = s.replaceAll(' ', '');
  if (!RegExp(r'^[\d\.,]+$').hasMatch(s)) return null;
  if (!RegExp(r'\d').hasMatch(s)) return null;

  String intPart;
  if (s.contains('.') && s.contains(',')) {
    // Indonesia: titik ribuan, koma desimal → "12.500,00" = 12500.
    s = s.replaceAll('.', '');
    intPart = s.split(',').first;
  } else if (s.contains(',')) {
    // Hanya koma: bisa desimal ("12.500,00" sudah ditangani di atas,
    // sisa: "250,00" = 250) atau ribuan Inggris ("25,000" = 25000).
    final parts = s.split(',');
    final last = parts.last;
    if (last.length == 2 && parts.length == 2 && !s.contains('.')) {
      // Heuristik desimal: "250,00". Kalau "25,000" (3 digit) = ribuan.
      intPart = parts.sublist(0, parts.length - 1).join('');
    } else if (last.length == 3 && parts.length > 1) {
      intPart = s.replaceAll(',', '');
    } else if (last.length == 2) {
      intPart = parts.sublist(0, parts.length - 1).join('');
    } else {
      intPart = s.replaceAll(',', '');
    }
  } else {
    // Hanya titik / digit: "25.000" = 25000, "25000" = 25000.
    // Titik tunggal sebagai desimal ("25.50") jarang di struk Rp —
    // anggap ribuan juga agar tidak under-read.
    intPart = s.replaceAll('.', '');
  }
  intPart = intPart.replaceAll(RegExp(r'[^0-9]'), '');
  if (intPart.isEmpty) return null;
  // Batas wajar rupiah (kuadriliun) — cegah overflow int.
  if (intPart.length > 15) return null;
  final v = int.tryParse(intPart);
  if (v == null || v <= 0) return null;
  return v;
}

/// Kata kunci baris total (skor tinggi) vs baris yang WAJIB dihindari
/// (tunai/kembali = uang yang diserahkan, bukan belanja).
final _totalKeywords = <String, int>{
  'grand total': 110,
  'grandtotal': 110,
  'total bayar': 105,
  'total belanja': 105,
  'total pembelian': 105,
  'total': 100,
  'jumlah bayar': 95,
  'jumlah': 90,
  'tagihan': 90,
  'subtotal': 80,
  'sub total': 80,
  'harga total': 85,
  'total akhir': 105,
};

final _bannedKeywords = <String>[
  'kembali',
  'kembalian',
  'change',
  'tunai',
  'cash',
  'tunai:',
  'dibayar',
  'bayar tunai',
  'uang bayar',
  'terima',
  'deposit',
  'saldo',
];

bool _isBannedLine(String lower) {
  for (final b in _bannedKeywords) {
    if (lower.contains(b)) return true;
  }
  return false;
}

int _lineScore(String lower) {
  var best = 0;
  _totalKeywords.forEach((k, score) {
    if (lower.contains(k) && score > best) best = score;
  });
  return best;
}

/// Ambil angka di ujung kanan baris (pola umum struk:
/// "TOTAL            Rp 45.000"). Return token mentahnya.
String? _trailingMoneyToken(String line) {
  // Cari semua kandidat angka, ambil yang paling kanan.
  final matches =
      RegExp(r'(?:rp\.?\s?|idr\s?)?[\d\.,]+').allMatches(line).toList();
  if (matches.isEmpty) return null;
  return matches.last.group(0);
}

/// Parse tanggal struk. Dukung:
/// - 08/10/2026, 8-10-2026, 08.10.26
/// - 8 Okt 2026 / 8 Oktober 2026 (Indonesia + Inggris)
DateTime? parseReceiptDate(String text, {DateTime? now}) {
  // `now` = referensi masa depan (mis. test butuh tanggal relatif);
  // saat ini parser tanggal absolut saja, jadi tidak dipakai.
  now ?? DateTime.now();

  // 1) Numerik: dd/mm/yyyy atau dd-mm-yy.
  final numeric =
      RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})').firstMatch(text);
  if (numeric != null) {
    final d = int.tryParse(numeric.group(1)!);
    final m = int.tryParse(numeric.group(2)!);
    var y = int.tryParse(numeric.group(3)!);
    if (d != null && m != null && y != null) {
      if (y < 100) y += 2000;
      if (d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 2000 && y <= 2100) {
        return DateTime(y, m, d);
      }
    }
  }

  // 2) "8 Okt 2026".
  final named = RegExp(
    r'(\d{1,2})\s+(jan\w*|feb\w*|mar\w*|apr\w*|mei|may|jun\w*|jul\w*|agu\w*|ags\w*|aug\w*|sep\w*|okt\w*|oct\w*|nov\w*|des\w*|dec\w*)\s+(\d{4})',
    caseSensitive: false,
  ).firstMatch(text);
  if (named != null) {
    final d = int.tryParse(named.group(1)!);
    final mon = named.group(2)!.toLowerCase();
    final y = int.tryParse(named.group(3)!);
    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'agu': 8,
      'ags': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
    };
    int? m;
    for (final e in monthMap.entries) {
      if (mon.startsWith(e.key)) {
        m = e.value;
        break;
      }
    }
    if (d != null && m != null && y != null && d >= 1 && d <= 31) {
      return DateTime(y, m, d);
    }
  }
  return null;
}

/// Tebak nama merchant: baris pertama yang mengandung huruf dan
/// panjang wajar (3–40 char). Simbol dekorasi (*, -, =) dibuang.
String? parseReceiptMerchant(String text) {
  final lines = text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  for (final line in lines) {
    final clean = line.replaceAll(RegExp(r'^[\*\-\=\#\s]+'), '').trim();
    if (clean.length < 3 || clean.length > 40) continue;
    final letters = RegExp(r'[A-Za-z]').allMatches(clean).length;
    if (letters < 3) continue;
    // Lewati baris yang jelas-jelas bukan nama toko.
    final lower = clean.toLowerCase();
    if (lower.contains('struk') ||
        lower.contains('nota') ||
        lower.contains('receipt') ||
        lower.contains('telp') ||
        lower.contains('jalan') ||
        lower.contains('jl.') ||
        RegExp(r'^\d+$').hasMatch(clean)) {
      continue;
    }
    return clean.length > 32 ? clean.substring(0, 32).trim() : clean;
  }
  return null;
}

/// Saran kategori dari kata kunci di seluruh teks struk.
/// Return = nama kategori persis seperti di [defaultCategories]
/// agar UI bisa lookup id-nya. null = "Tanpa kategori".
///
/// PENTING: pencocokan memakai word-boundary (`\b`), BUKAN substring
/// polos — substring bikin false-positive ("tol" ke-match di "botol",
/// "bus" di "busana", "rm" di "farmasi").
bool _hasWord(String hayLower, String needle) {
  final n = needle.trim().toLowerCase();
  if (n.isEmpty) return false;
  return RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(hayLower);
}

bool _hasAnyWord(String hayLower, List<String> keys) {
  for (final k in keys) {
    if (_hasWord(hayLower, k)) return true;
  }
  return false;
}

String? suggestCategoryForText(String text) {
  final t = text.toLowerCase();

  // Tagihan dulu (paling spesifik, jangan ketiban "belanja").
  if (_hasAnyWord(t, [
    'pln',
    'listrik',
    'token listrik',
    'pdam',
    'air bersih',
    'telkom',
    'indihome',
    'pajak',
    'pbb',
    'iuran',
  ])) {
    return 'Tagihan';
  }
  // Kesehatan.
  if (_hasAnyWord(t, [
    'apotek',
    'apotik',
    'klinik',
    'rumah sakit',
    'rsud',
    'puskesmas',
    'dokter',
    'farmasi',
    'obat',
  ])) {
    return 'Kesehatan';
  }
  // Transportasi / bensin.
  if (_hasAnyWord(t, [
    'pertamina',
    'shell',
    'spbu',
    'bensin',
    'pertalite',
    'pertamax',
    'solar',
    'parkir',
    'tol',
    'gojek',
    'grab',
    'gocar',
    'grabbike',
    'tiket kereta',
    'kai',
    'bus',
    'travel',
  ])) {
    return 'Transportasi';
  }
  // Makan & minum.
  if (_hasAnyWord(t, [
    'resto',
    'restoran',
    'warteg',
    'warung makan',
    'rm',
    'kopi',
    'kafe',
    'cafe',
    'ayam',
    'bakso',
    'soto',
    'sate',
    'nasgor',
    'nasi goreng',
    'mie',
    'mcd',
    "mcdonald",
    'kfc',
    'starbucks',
    'janji jiwa',
    'kopi kenangan',
    'pizza',
    'burger',
    'seafood',
    'kantin',
    'catering',
  ])) {
    return 'Makan & Minum';
  }
  // Pendidikan.
  if (_hasAnyWord(t, [
    'sekolah',
    'kampus',
    'universitas',
    'kursus',
    'bimbel',
    'gramedia',
    'toko buku',
    'fotocopy',
    'fotokopi',
    'print',
  ])) {
    return 'Pendidikan';
  }
  // Hiburan.
  if (_hasAnyWord(t, [
    'bioskop',
    'xxi',
    'cgv',
    'cineplex',
    'karaoke',
    'game',
    'playstation',
    'tiket wisata',
    'taman',
  ])) {
    return 'Hiburan';
  }
  // Belanja (minimarket & retail umum).
  if (_hasAnyWord(t, [
    'indomaret',
    'alfamart',
    'alfamidi',
    'super indo',
    'hypermart',
    'carrefour',
    'giant',
    'minimarket',
    'supermarket',
    'swalayan',
    'mall',
    'plaza',
    'tokopedia',
    'shopee',
    'blibli',
    'lazada',
  ])) {
    return 'Belanja';
  }
  return null;
}

/// Parse lengkap satu teks OCR struk.
ReceiptDraft parseReceiptText(String raw, {DateTime? now}) {
  final text = raw.trim();
  if (text.isEmpty) return const ReceiptDraft();

  final lines = text.split('\n');
  int? bestAmount;
  var bestScore = -1;
  int? fallbackMax;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final lower = trimmed.toLowerCase();
    final token = _trailingMoneyToken(trimmed);
    if (token == null) continue;
    final value = parseMoneyToken(token);
    if (value == null) continue;

    // Simpan kandidat terbesar sebagai fallback (buat struk tanpa
    // label TOTAL yang jelas).
    if (fallbackMax == null || value > fallbackMax) fallbackMax = value;

    if (_isBannedLine(lower)) continue;
    final score = _lineScore(lower);
    if (score <= 0) continue;
    // Bila skor sama, ambil nominal terbesar (mis. ada 2 baris TOTAL).
    if (score > bestScore ||
        (score == bestScore &&
            (bestAmount == null || value > bestAmount))) {
      bestScore = score;
      bestAmount = value;
    }
  }

  // Fallback: tidak ada baris TOTAL — pakai angka terbesar, TAPI
  // abaikan baris tunai/kembali agar tidak salah ambil uang bayar.
  if (bestAmount == null) {
    int? maxUnbanned;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isBannedLine(trimmed.toLowerCase())) continue;
      final token = _trailingMoneyToken(trimmed);
      if (token == null) continue;
      final value = parseMoneyToken(token);
      if (value == null) continue;
      if (maxUnbanned == null || value > maxUnbanned) {
        maxUnbanned = value;
      }
    }
    bestAmount = maxUnbanned ?? fallbackMax;
  }

  final merchant = parseReceiptMerchant(text);
  final date = parseReceiptDate(text, now: now);
  final suggested = suggestCategoryForText(text);
  final note = merchant != null ? '$merchant — scan struk' : null;

  return ReceiptDraft(
    amount: bestAmount,
    date: date,
    merchant: merchant,
    note: note,
    suggestedCategory: suggested,
  );
}
