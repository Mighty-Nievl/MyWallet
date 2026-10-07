# 01 — Visi & Ruang Lingkup

## Masalah
Mencatat keuangan pribadi sering gagal bukan karena niat, tapi karena aplikasinya ribet: harus daftar akun, butuh internet, atau fiturnya kebanyakan sampai malas dibuka.

## Visi
**MyWallet** = aplikasi pencatat keuangan pribadi yang dibuka dalam 2 detik, mencatat dalam 10 detik, dan datanya milik pengguna sepenuhnya (tersimpan di HP).

## Pengguna
- Satu pengguna per HP (personal, bukan multi-user).
- Bahasa Indonesia, nominal Rupiah bilangan bulat.

## MVP v1.0.0 (sudah jadi)

| Fitur | Status |
|---|---|
| Dashboard: saldo + ringkasan bulan + top kategori + terakhir dicatat | ✅ |
| Catat transaksi (masuk/keluar, nominal, kategori, tanggal, catatan) | ✅ |
| Edit & hapus transaksi | ✅ |
| Kategori custom (nama + emoji) | ✅ |
| Riwayat + filter (tipe, kategori, kata kunci) | ✅ |
| Budget bulanan per kategori + progress bar + peringatan lewat batas | ✅ |
| Laporan: grafik 6 bulan + pie kategori | ✅ |
| Export CSV (share sheet) | ✅ |
| Offline-first, tanpa login | ✅ |

## v1.1.0 (7 Okt 2026 — sudah jadi)
Layout baru + P0 Pengaturan lengkap.

| Fitur | Status |
|---|---|
| Bottom bar [home] [history] [+] [budget] [laporan], + di tengah | ✅ |
| Settings pindah ke ikon kanan atas Beranda | ✅ |
| Tema Terang/Gelap/Ikuti HP | ✅ |
| Sembunyikan saldo (toggle di kartu + di Pengaturan) | ✅ |
| Saldo awal | ✅ |
| Kunci aplikasi PIN (hash di secure storage) / biometrik + LockScreen | ✅ |
| Pengingat harian terjadwal (izin runtime Android 13+, pulih tiap buka app) | ✅ |
| Backup DB (`VACUUM INTO`), restore, hapus semua data (konfirmasi dobel) | ✅ |
| Versi otomatis di Tentang (`package_info_plus`) | ✅ |

## v1.2.0 (7 Okt 2026 — sudah jadi)
Tampilan full + overkill.

| Fitur | Status |
|---|---|
| Warna aksen (6 pilihan) + ikuti wallpaper HP (Material You) | ✅ |
| Hitam pekat mode gelap | ✅ |
| Sembunyikan semua nominal (saldo + list + laporan) | ✅ |
| Nominal ringkas (Rp1,5 jt) | ✅ |
| Kustom Beranda (ringkasan / top kategori / terakhir 3-5-10) | ✅ |
| Overkill: ukuran font, list rapat, tanggal relatif, ikon kategori on/off | ✅ |

## Bukan bagian MVP (lihat [[06-Roadmap]])
Sinkronisasi cloud, multi-dompet/rekening, scan struk OCR, widget home screen, input cepat parsing.
