/// Changelog in-app MyWallet — SATU-SATUNYA sumber teks changelog.
///
/// Aturan wajib tiap build / naik versi:
/// - Urutan terbaru dulu.
/// - `version` format `vX.Y.Z`, cocok dengan `version:` di pubspec.yaml
///   (tanpa `+build`, contoh pubspec `1.9.0+14` -> `v1.9.0`).
/// - Tiap naik versi di pubspec WAJIB tambah entri baru paling atas.
/// - Dialog Tentang (`showChangelog` di `settings_actions.dart`) wajib
///   ambil teks dari sini via [formatChangelog], JANGAN hardcode lagi.
/// - `docs/07-Rilis-dan-Obtainium.md` + README wajib diupdate bareng.
/// - `test/changelog_test.dart` gagal bila entri teratas beda dengan pubspec.
const appChangelog = <({String version, String text})>[
  (
    version: 'v1.10.1',
    text:
        'Penyeragaman: FAB Catat tertanam via BottomAppBar notch + Beranda CustomScrollView satu-sliver-per-section + ikon monochrome di semua layar (CategoryIcon lama dihapus).',
  ),
  (
    version: 'v1.10.0',
    text:
        'Beranda baru: kartu saldo aksen + teks putih, progress budget bertrack, nama kategori lebih besar, ikon monochrome aksen, teks transaksi kontras, tombol Catat jadi FAB melayang.',
  ),
  (
    version: 'v1.9.0',
    text:
        'Redesign STEP 4: Kategori + Pengaturan + Lock Screen baru (visual saja, logika utuh).',
  ),
  (
    version: 'v1.8.0',
    text:
        'Budget rapi: edit beneran + hapus aman + undo 5 detik + validasi inline + overview aman.',
  ),
  (
    version: 'v1.7.2',
    text:
        'Fix list budget tetap kosong setelah simpan + SnackBar tersimpan.',
  ),
  (
    version: 'v1.7.1',
    text:
        'Fix tombol Tambah Budget: dialog instan + SnackBar bila belum lengkap.',
  ),
  (
    version: 'v1.7.0',
    text:
        'Redesign STEP 3: navigasi bawah custom + Budget + Laporan baru (visual saja).',
  ),
  (
    version: 'v1.6.0',
    text: 'Redesign STEP 2: Riwayat + Form Transaksi baru (visual saja).',
  ),
  (
    version: 'v1.5.0',
    text: 'Redesign STEP 1: tokens + TxTile + Beranda baru (visual saja).',
  ),
  (
    version: 'v1.4.0',
    text:
        'Pengaturan multi-halaman + input nominal otomatis bertitik + border seragam.',
  ),
  (
    version: 'v1.3.0',
    text:
        'Restruktur Pengaturan (cari, 4 grup, kelola kategori sendiri, tentang tap-to-copy) + ringkasan harian di Beranda.',
  ),
  (
    version: 'v1.2.1',
    text: 'Warna semantik ikut colorScheme + palet pie tanpa hijau.',
  ),
  (
    version: 'v1.2.0',
    text:
        'Tampilan full (aksen, Material You, true black, privacy all, nominal ringkas, kustom Beranda, overkill).',
  ),
  (
    version: 'v1.1.0',
    text: 'P0 Pengaturan + bottom bar baru.',
  ),
  (
    version: 'v1.0.1',
    text: 'Fix saldo reaktif.',
  ),
  (
    version: 'v1.0.0',
    text: 'MVP awal.',
  ),
];

/// Teks siap tampil di dialog Changelog (dipakai `showChangelog`).
String formatChangelog() =>
    appChangelog.map((e) => '${e.version} — ${e.text}').join('\n\n');
