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
    version: 'v1.13.0',
    text:
        'Beranda pola GoPay: kepala sapaan berwarna aksen + kartu saldo gradien ikut warna tema (kontras putih ≥4.5:1, 48 pengukuran 6 aksen × 2 tema), aksi cepat Catat/Riwayat/Budget/Laporan, banner insight (delta vs bulan lalu + pacing budget + CTA), tile metrik Masuk/Keluar/Hari ini. Logika/provider/query tidak berubah.',
  ),
  (
    version: 'v1.12.1',
    text:
        'Polish Beranda: semantik nominal satu sumber (AppColors income/expense + varian hero), delta % via provider (tanpa query ulang tiap rebuild), CTA "Atur budget" saat kosong, strip hari ini jelas saat nol, hero berboder di dark mode, golden test + uji kontras WCAG 4.5:1. README baru ala landing page.',
  ),
  (
    version: 'v1.12.0',
    text:
        'Beranda menjawab "bulan ini aman nggak?": header sapaan pinned (gear tidak hilang), hero netral + arus semantik + delta vs bulan lalu + pacing budget, kategori proporsional + persen, riwayat tergrup tanggal + chevron, navigasi M3 NavigationBar, skeleton shimmer + error ramah di semua layar.',
  ),
  (
    version: 'v1.11.0',
    text:
        'Logo MyWallet + Micro-UX premium: FAB Container Transform (OpenContainer) jadi form Catat, nominal autofocus + quick-add chips, haptic di FAB/kategori/simpan, empty state memotivasi, nama aplikasi MyWallet.',
  ),
  (
    version: 'v1.10.2',
    text:
        'Fix bar bawah: blok hitam belang hilang + notch FAB rapat (extendBody + buang SafeArea pembungkus, visual saja).',
  ),
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
