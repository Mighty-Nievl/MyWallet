/// Sapaan Beranda production-grade (v1.18): berbasis waktu + resolusi nama
/// (manual → akun Google → polos). Murni + unit-testable, tanpa konteks.
///
/// Aturan nama: setting manual (Pengaturan → Tampilan → Nama sapaan)
/// menang bila diisi; kosong = ikut nama akun Google; keduanya kosong =
/// sapaan polos TANPA koma ("Selamat pagi", bukan "Selamat pagi, ").
library;

/// Judul sapaan berbasis jam (24h): pagi 04–11, siang 11–15,
/// sore 15–19, malam sisanya.
String greetingTitle(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return 'Selamat pagi';
  if (h >= 11 && h < 15) return 'Selamat siang';
  if (h >= 15 && h < 19) return 'Selamat sore';
  return 'Selamat malam';
}

/// Nama sapaan: manual (trim) menang; kosong → Google (trim);
/// keduanya kosong → null.
String? resolveGreetingName({String? manualName, String? googleName}) {
  final m = (manualName ?? '').trim();
  if (m.isNotEmpty) return m;
  final g = (googleName ?? '').trim();
  if (g.isNotEmpty) return g;
  return null;
}

/// "Selamat pagi, ReWin" / "Selamat pagi" (tanpa nama = tanpa koma).
String greetingText(
  DateTime now, {
  String? manualName,
  String? googleName,
}) {
  final title = greetingTitle(now);
  final name = resolveGreetingName(
    manualName: manualName,
    googleName: googleName,
  );
  return name == null ? title : '$title, $name';
}
