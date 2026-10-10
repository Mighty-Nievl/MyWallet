/// Changelog in-app MyWallet — SATU-SATUNYA sumber teks changelog.
///
/// Aturan wajib tiap build / naik versi:
/// - Urutan terbaru dulu.
/// - `version` format `vX.Y.Z`, cocok dengan `version:` di pubspec.yaml
///   (tanpa `+build`, contoh pubspec `1.9.0+14` -> `v1.9.0`).
/// - `date` format `8 Okt 2026`, cocok dengan `docs/07-Rilis-dan-Obtainium.md`.
/// - Tiap naik versi di pubspec WAJIB tambah entri baru paling atas.
/// - `user`: bahasa manusia, 1-2 kalimat, menjawab "apa untungnya buat
///   saya?". DILARANG istilah internal (uuid, skema DB, plugin, minSdk,
///   nama paket/secret/CI, singkatan Fase tanpa penjelasan).
///   Dijaga otomatis oleh `test/changelog_test.dart`.
/// - `tech`: detail teknis untuk yang penasaran — tampil collapsed
///   ("Detail teknis") di halaman Changelog, tidak mengganggu pembaca biasa.
/// - `breaking`: hanya bila update butuh tindakan user (backup dulu,
///   install baru, izin baru). Wajib menyebut jalan keluarnya.
/// - Halaman Changelog (`lib/ui/screens/changelog_screen.dart`) wajib
///   ambil teks dari sini, JANGAN hardcode lagi.
/// - `docs/07-Rilis-dan-Obtainium.md` + README wajib diupdate bareng.
/// - `test/changelog_test.dart` gagal bila entri teratas beda dengan pubspec.
const appChangelog = <({
  String version,
  String date,
  String user,
  String tech,
  String? breaking,
})>[
  (
    version: 'v1.17.1',
    date: '10 Okt 2026',
    user:
        'Halaman Keluarga dirapikan: ada penjelasan manfaat + tombol masuk '
        'yang besar, dan kalau login gagal pesannya jelas (ada tombol Coba '
        'lagi), bukan tulisan samar di bawah.',
    tech:
        'UX Keluarga: hero empty-state + error card inline (kontras tinggi, '
        'ada retry), perluas friendlyAuthError (config v7, provider '
        'nonaktif), AuthService null-safe tanpa Firebase init, '
        'family_ux_test. Full 127/127.',
    breaking: null,
  ),
  (
    version: 'v1.17.0',
    date: '10 Okt 2026',
    user:
        'Baru: menu Keluarga di Pengaturan. Masuk dengan akun Google untuk '
        'membuat rumah tangga dan mengundang pasangan pakai kode (atau '
        'gabung pakai kode dari pasangan). Tanpa login, aplikasi tetap '
        '100% offline seperti biasa.',
    tech:
        'Keluarga Fase 1 (opt-in): google_sign_in v7 → Firebase Auth + '
        'Firestore mywallet-7614d, household.dart murni (invite 8 char, '
        'TTL 24 jam), auth_service + layar Keluarga, firestore.rules '
        'anggota-only (koleksi sync tx/cats ditolak sampai Fase 2).',
    breaking: null,
  ),
  (
    version: 'v1.16.2',
    date: '10 Okt 2026',
    user:
        'Perbaikan penting buat yang pakai backup: pulihkan backup, hapus '
        'semua data, dan pindah dari aplikasi lama sekarang anti-gagal '
        '(sebelumnya bisa macet dengan pesan error koneksi database).',
    tech:
        'Lokasi file DB dihitung langsung tanpa query (aman setelah koneksi '
        'ditutup), WAL checkpoint sebelum backup, validasi header SQLite '
        'sebelum timpa (file sampah ditolak, data aman). Restore '
        'antar-package v1.16.0 → v1.16.1+ bisa jalan.',
    breaking: null,
  ),
  (
    version: 'v1.16.1',
    date: '10 Okt 2026',
    user:
        'Persiapan pindah ke aplikasi resmi + fondasi login Google dan '
        'sinkronisasi antar-HP di update berikutnya (belum aktif — aplikasi '
        'tetap 100% offline, datamu tidak dikirim ke mana pun).',
    tech:
        'Ganti package Android ke com.rezal.mywallet + wiring Firebase Fase 1 '
        '(project mywallet-7614d): plugin google-services 4.5.0, firebase_core '
        'init aman-gagal (tanpa config = tetap offline murni), paket '
        'firebase_auth + cloud_firestore + google_sign_in v7, minSdk 23. '
        'google-services.json di-gitignore + CI via secret.',
    breaking:
        'Update ini terinstall sebagai aplikasi BARU (data mulai dari nol) — '
        'backup dulu via Kelola sebelum update.',
  ),
  (
    version: 'v1.16.0',
    date: '10 Okt 2026',
    user:
        'Tidak ada yang berubah di tampilan — ini fondasi di balik layar '
        'agar datamu nanti bisa sinkron antar-HP (misalnya HP pribadi dan HP '
        'bersama pasangan). Datamu tetap 100% tersimpan di HP.',
    tech:
        'Fondasi sync-ready Fase 0 (tetap 100% offline, tanpa network): skema '
        'DB v3 — semua tabel punya uuid (identitas antar-HP), updatedAt '
        '(jejak tulis), deletedAt (soft-delete), householdId (pribadi vs rumah '
        'tangga) + categoryUuid di transaksi. Migrasi v2→v3 aman (data lama '
        'utuh, backfill otomatis). Semua query (saldo/laporan/riwayat/budget/'
        'utang) siap soft-delete. Persiapan Google Sign-In + Firestore '
        '(Fase 1-2).',
    breaking: null,
  ),
  (
    version: 'v1.15.0',
    date: '9 Okt 2026',
    user:
        'Baru: tab Utang. Catat utang dan piutang, bayar/terima cicilan '
        'berkali-kali dengan pengingat jatuh tempo, otomatis lunas saat sudah '
        'pas. Semua ikut tercatat di saldo dan laporan seperti biasa.',
    tech:
        'Manajer utang-piutang (100% offline): tab Utang ke-5 + kartu ringkas '
        'di Beranda (sisa utang vs piutang, tap → Kelola). Utang = pinjam '
        '(catat = pemasukan, bayar = pengeluaran), Piutang = meminjami '
        '(catat = pengeluaran, terima = pemasukan) — tiap aksi menulis '
        'transaksi cermin otomatis sehingga saldo, laporan, riwayat, PDF & '
        'CSV ikut tanpa ubah query lama. Cicilan parsial berkali-kali + '
        'anti-overpay + jatuh tempo + progress + lunas otomatis. Skema DB v2 '
        '(migrasi v1→v2 aman, data lama utuh).',
    breaking: null,
  ),
  (
    version: 'v1.14.0',
    date: '8 Okt 2026',
    user:
        'Baru: kirim laporan bulanan sebagai file PDF (bisa dibagikan via '
        'WA), dan catat belanja cukup dengan memfoto struk — nominal, tanggal, '
        'dan nama warung terisi otomatis, kamu tinggal cek lalu simpan.',
    tech:
        'Export PDF laporan + Scan struk (100% offline): tombol PDF di Laporan '
        '& Kelola (ringkasan Masuk/Keluar/Selisih + rincian kategori % + '
        'daftar transaksi, via share sheet / simpan file, tanpa server/'
        'API-key); tombol scan di form Catat (kamera/galeri → ML Kit on-device '
        '→ prefill nominal + tanggal + warung + saran kategori, user tetap cek '
        '& Simpan manual). Izin kamera baru. Logika simpan/transaksi tidak '
        'berubah.',
    breaking:
        'Butuh izin kamera baru saat pertama pakai scan struk.',
  ),
  (
    version: 'v1.13.1',
    date: '8 Okt 2026',
    user:
        'Tampilan Beranda baru: sapaan personal dengan namamu, kartu saldo '
        'warna-warni mengikuti warna tema pilihanmu di Pengaturan.',
    tech:
        'Samakan Beranda dengan mockup ala GoPay: sapaan personal '
        '“Hai, {nama}” (baru di Pengaturan → Tampilan → Nama sapaan, default '
        'Nievi) dengan ikon mahkota, tanggal panjang, label saldo, nav bulan '
        'hanya saat menjelajah bulan lain, aksi cepat 4 chip, tile metrik '
        'Masuk/Keluar/SISA BUDGET, ringkasan “Hari ini” pindah ke seksi '
        'Terakhir dicatat. Warna dijenuhkan (+35%); kontras putih ≥4.5:1. '
        'Logika/provider/query tidak berubah.',
    breaking: null,
  ),
  (
    version: 'v1.13.0',
    date: '8 Okt 2026',
    user:
        'Beranda pola baru: kepala sapaan berwarna, kartu saldo gradien, '
        'jalan pintas, info perbandingan bulan lalu, dan status budget sekilas.',
    tech:
        'Beranda pola GoPay: kepala sapaan berwarna aksen + kartu saldo '
        'gradien ikut warna tema (kontras putih ≥4.5:1, 48 pengukuran 6 aksen '
        '× 2 tema), aksi cepat Catat/Riwayat/Budget/Laporan, banner insight '
        '(delta vs bulan lalu + pacing budget + CTA), tile metrik '
        'Masuk/Keluar/Hari ini. Logika/provider/query tidak berubah.',
    breaking: null,
  ),
  (
    version: 'v1.12.1',
    date: '8 Okt 2026',
    user:
        'Beranda makin rapi dan cepat: angka pemasukan/pengeluaran konsisten '
        'di semua layar, tombol atur budget muncul saat dibutuhkan.',
    tech:
        'Polish Beranda: semantik nominal satu sumber (AppColors '
        'income/expense + varian hero), delta % via provider (tanpa query '
        'ulang tiap rebuild), CTA "Atur budget" saat kosong, strip hari ini '
        'jelas saat nol, hero berboder di dark mode, golden test + uji kontras '
        'WCAG 4.5:1. README baru ala landing page.',
    breaking: null,
  ),
  (
    version: 'v1.12.0',
    date: '8 Okt 2026',
    user:
        'Beranda kini menjawab “bulan ini aman nggak?” sekilas: arus kas, '
        'perbandingan dengan bulan lalu, dan status budget — plus navigasi '
        'bawah baru yang lebih rapi.',
    tech:
        'Beranda menjawab "bulan ini aman nggak?": header sapaan pinned (gear '
        'tidak hilang), hero netral + arus semantik + delta vs bulan lalu + '
        'pacing budget, kategori proporsional + persen, riwayat tergrup '
        'tanggal + chevron, navigasi M3 NavigationBar, skeleton shimmer + '
        'error ramah di semua layar.',
    breaking: null,
  ),
  (
    version: 'v1.11.0',
    date: '8 Okt 2026',
    user:
        'Logo baru + pengalaman catat lebih mulus: tombol + melebar jadi form, '
        'nominal terisi otomatis saat diketik, ada getaran halus di tiap sentuhan.',
    tech:
        'Logo MyWallet + Micro-UX premium: FAB Container Transform '
        '(OpenContainer) jadi form Catat, nominal autofocus + quick-add chips, '
        'haptic di FAB/kategori/simpan, empty state memotivasi, nama aplikasi '
        'MyWallet.',
    breaking: null,
  ),
  (
    version: 'v1.10.2',
    date: '8 Okt 2026',
    user: 'Perbaikan tampilan bar bawah (blok hitam belang hilang).',
    tech:
        'Fix bar bawah: blok hitam belang hilang + notch FAB rapat (extendBody '
        '+ buang SafeArea pembungkus, visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.10.1',
    date: '8 Okt 2026',
    user:
        'Tombol + Catat menyatu rapi di bar bawah, ikon seragam di semua layar.',
    tech:
        'Penyeragaman: FAB Catat tertanam via BottomAppBar notch + Beranda '
        'CustomScrollView satu-sliver-per-section + ikon monochrome di semua '
        'layar (CategoryIcon lama dihapus).',
    breaking: null,
  ),
  (
    version: 'v1.10.0',
    date: '8 Okt 2026',
    user:
        'Beranda baru: kartu saldo berwarna, progress budget lebih jelas, '
        'tombol Catat melayang yang mudah dijangkau jempol.',
    tech:
        'Beranda baru: kartu saldo aksen + teks putih, progress budget '
        'bertrack, nama kategori lebih besar, ikon monochrome aksen, teks '
        'transaksi kontras, tombol Catat jadi FAB melayang.',
    breaking: null,
  ),
  (
    version: 'v1.9.0',
    date: '7 Okt 2026',
    user: 'Tampilan Kategori, Pengaturan, dan Kunci Layar baru yang seragam.',
    tech:
        'Redesign STEP 4: Kategori + Pengaturan + Lock Screen baru (visual '
        'saja, logika utuh).',
    breaking: null,
  ),
  (
    version: 'v1.8.0',
    date: '7 Okt 2026',
    user:
        'Budget bisa diedit dan dihapus dengan aman (ada tombol urungkan 5 '
        'detik kalau salah hapus), plus ringkasan “X dari Y aman”.',
    tech:
        'Budget rapi: edit beneran + hapus aman + undo 5 detik + validasi '
        'inline + overview aman.',
    breaking: null,
  ),
  (
    version: 'v1.7.2',
    date: '7 Okt 2026',
    user:
        'Perbaikan: budget yang baru disimpan sekarang langsung muncul di daftar.',
    tech:
        'Fix list budget tetap kosong setelah simpan + SnackBar tersimpan.',
    breaking: null,
  ),
  (
    version: 'v1.7.1',
    date: '7 Okt 2026',
    user: 'Perbaikan: tombol Tambah Budget sekarang langsung membuka dialog.',
    tech:
        'Fix tombol Tambah Budget: dialog instan + SnackBar bila belum lengkap.',
    breaking: null,
  ),
  (
    version: 'v1.7.0',
    date: '7 Okt 2026',
    user: 'Tampilan Budget dan Laporan baru yang lebih jelas dan rapi.',
    tech:
        'Redesign STEP 3: navigasi bawah custom + Budget + Laporan baru '
        '(visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.6.0',
    date: '7 Okt 2026',
    user: 'Tampilan Riwayat dan Form Catat baru yang lebih nyaman dipakai.',
    tech:
        'Redesign STEP 2: Riwayat + Form Transaksi baru (visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.5.0',
    date: '7 Okt 2026',
    user: 'Tampilan Beranda baru yang lebih bersih dan modern.',
    tech: 'Redesign STEP 1: tokens + TxTile + Beranda baru (visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.4.0',
    date: '7 Okt 2026',
    user:
        'Pengaturan kini multi-halaman dan bisa dicari, nominal otomatis '
        'bertitik saat diketik.',
    tech:
        'Pengaturan multi-halaman + input nominal otomatis bertitik + border '
        'seragam.',
    breaking: null,
  ),
  (
    version: 'v1.3.0',
    date: '7 Okt 2026',
    user:
        'Pengaturan dirapikan (ada kolom cari + kelola kategori sendiri), '
        'Beranda dapat ringkasan harian.',
    tech:
        'Restruktur Pengaturan (cari, 4 grup, kelola kategori sendiri, tentang '
        'tap-to-copy) + ringkasan harian di Beranda.',
    breaking: null,
  ),
  (
    version: 'v1.2.1',
    date: '7 Okt 2026',
    user: 'Warna angka pemasukan/pengeluaran ikut tema HP.',
    tech: 'Warna semantik ikut colorScheme + palet pie tanpa hijau.',
    breaking: null,
  ),
  (
    version: 'v1.2.0',
    date: '7 Okt 2026',
    user:
        'Tampilan full: 6 warna aksen pilihan, mode hitam pekat, saldo bisa '
        'disembunyikan, Beranda bisa dikustom sesukamu.',
    tech:
        'Tampilan full (aksen, Material You, true black, privacy all, nominal '
        'ringkas, kustom Beranda, overkill).',
    breaking: null,
  ),
  (
    version: 'v1.1.0',
    date: '7 Okt 2026',
    user:
        'Halaman Pengaturan pertama: tema, kunci PIN, pengingat harian, dan '
        'backup data.',
    tech: 'P0 Pengaturan + bottom bar baru.',
    breaking: null,
  ),
  (
    version: 'v1.0.1',
    date: '7 Okt 2026',
    user: 'Perbaikan: saldo langsung berubah setiap ada transaksi baru.',
    tech: 'Fix saldo reaktif.',
    breaking: null,
  ),
  (
    version: 'v1.0.0',
    date: '7 Okt 2026',
    user: 'Rilis pertama: catat pemasukan-pengeluaran harian, 100% offline.',
    tech: 'MVP awal.',
    breaking: null,
  ),
];

/// Teks siap tampil / siap salin (dipakai halaman Changelog + laporan bug).
String formatChangelog() => appChangelog
    .map((e) => '${e.version} (${e.date}) — ${e.user}')
    .join('\n\n');
