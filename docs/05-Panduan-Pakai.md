# 05 — Panduan Pakai

## Beranda
- Kartu hijau = **saldo** (saldo awal + total masuk − total keluar sepanjang waktu) + ringkasan masuk/keluar **bulan yang dipilih**.
- Kartu **Hari ini** = masuk / keluar / selisih **tanggal berjalan** (00:00–23:59 waktu HP). Ikut mode privacy + nominal ringkas. Bisa dimatikan dari Pengaturan → Tampilan → Isi Beranda → Ringkasan hari ini.
- Ikon mata di kartu = sembunyikan/tampilkan saldo cepat (mode privacy).
- Ikon ⚙️ kanan atas = **Pengaturan**.
- Panah `<` `>` untuk pindah bulan.
- Bar di bawahnya = 5 kategori pengeluaran terbesar bulan itu.
- "Terakhir dicatat" = 5 transaksi terbaru — ketuk untuk edit.

## Navigasi bawah
`[ home ] [ history ] [ + ] [ budget ] [ laporan ]` — tombol **+** di tengah untuk mencatat.

## Mencatat (tombol + tengah)
1. Pilih **Keluar** / **Masuk**.
2. Isi nominal (ketik angka saja — titik otomatis muncul, cth. ketik `25000` jadi `25.000`).
3. Pilih kategori (atau "+ Tambah kategori baru").
4. Catatan opsional, tanggal bisa diubah (default hari ini).
5. Simpan. Saldo & ringkasan langsung berubah.

## Riwayat
- Kolom cari untuk catatan, chip **Semua/Keluar/Masuk**, chip kategori untuk filter.
- Ikon kalender kanan atas = lompat ke bulan tertentu.
- Ketuk baris untuk edit/hapus.

## Budget
- Satu budget = satu kategori + satu bulan. Contoh: Makan & Minum Rp1.500.000 untuk Oktober 2026.
- Bar hijau → oranye (≥80%) → merah + label LEWAT jika jebol.
- "Tambah / Ubah Budget" untuk menambah kategori lain atau mengubah batas.

## Laporan
- Grafik batang 6 bulan (hijau = masuk, merah = keluar).
- Pie + rincian pengeluaran per kategori bulan berjalan.

## Pengaturan (ikon ⚙️ kanan atas Beranda)
Halaman hub berisi 4 grup — ketuk untuk buka sub-halaman masing-masing. Kolom cari di hub memfilter semua item; ketuk hasil untuk lompat ke sub-halamannya.
- **Tampilan:** tema Terang/Gelap/Ikuti HP, warna aksen (6 pilihan) atau ikuti wallpaper HP (Material You, Android 12+), hitam pekat (mode gelap), ukuran font, nominal ringkas (Rp1,5 jt).
  - *Isi Beranda:* ringkasan hari ini, ringkasan masuk-keluar, top kategori, terakhir dicatat (3/5/10).
  - *List & tanggal:* list rapat, tanggal relatif (Hari ini/Kemarin), ikon kategori on/off.
- **Saldo & Privasi:** sembunyikan saldo (hanya saldo / semua nominal), saldo awal, kunci aplikasi PIN/biometrik, pengingat harian.
- **Kelola:** kelola kategori (halaman sendiri: tambah/hapus), export CSV, backup database, restore (kuning: menimpa semua data), hapus semua data (merah, konfirmasi 2x ketik HAPUS).
  - **Export CSV**: membuat file `mywallet-<timestamp>.csv` (kolom: tanggal, tipe, kategori, nominal, catatan) lalu dibuka lewat share sheet.
  - **Backup database**: salinan konsisten `mywallet.sqlite` ke file pilihan.
  - **Restore database**: kembalikan dari file backup, lalu tutup total aplikasi + buka lagi.
  - **Hapus semua data**: reset total (konfirmasi 2x, ketik HAPUS), lalu restart aplikasi.
