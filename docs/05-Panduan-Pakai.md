# 05 — Panduan Pakai

## Beranda
- Kartu hijau = **saldo** (saldo awal + total masuk − total keluar sepanjang waktu) + ringkasan masuk/keluar **bulan yang dipilih**.
- Ikon mata di kartu = sembunyikan/tampilkan saldo cepat (mode privacy).
- Ikon ⚙️ kanan atas = **Pengaturan**.
- Panah `<` `>` untuk pindah bulan.
- Bar di bawahnya = 5 kategori pengeluaran terbesar bulan itu.
- "Terakhir dicatat" = 5 transaksi terbaru — ketuk untuk edit.

## Navigasi bawah
`[ home ] [ history ] [ + ] [ budget ] [ laporan ]` — tombol **+** di tengah untuk mencatat.

## Mencatat (tombol + tengah)
1. Pilih **Keluar** / **Masuk**.
2. Isi nominal (angka saja, cth. `25000`).
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
- **Tampilan:** tema Terang/Gelap/Ikuti HP + sembunyikan saldo.
- **Keuangan:** saldo awal (uang yang sudah dipegang sebelum mulai mencatat).
- **Kategori:** tambah/hapus. Menghapus kategori membuat transaksinya jadi "Tanpa kategori", bukan ikut terhapus.
- **Keamanan:** kunci aplikasi PIN / biometrik.
- **Pengingat harian:** notifikasi "sudah catat belum?" tiap hari di jam pilihan.
- **Data:**
  - **Export CSV**: membuat file `mywallet-<timestamp>.csv` (kolom: tanggal, tipe, kategori, nominal, catatan) lalu dibuka lewat share sheet.
  - **Backup database**: salinan konsisten `mywallet.sqlite` ke file pilihan.
  - **Restore database**: kembalikan dari file backup, lalu tutup total aplikasi + buka lagi.
  - **Hapus semua data**: reset total (konfirmasi 2x, ketik HAPUS), lalu restart aplikasi.
