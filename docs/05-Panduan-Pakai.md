# 05 — Panduan Pakai

## Beranda
- **Carousel dompet** = satu kartu per dompet + kartu Kelola; geser untuk pindah, kartu tampil = filter aktif (ketuk kartu → detail dompet).
- **Kartu Pengeluaran** + switcher **Harian/Mingguan/Bulanan/Tahunan**, chevron `<` `>` untuk geser satu unit, dan chip **Kalender**. Periode ini dipakai bersama oleh Beranda, Riwayat, dan Laporan.
- Ikon mata di kartu = sembunyikan/tampilkan nominal cepat (mode privacy).
- Ikon ⚙️ kanan atas = **Pengaturan**; avatar/sapaan = **Profil**.
- Aksi cepat: **Catat masuk**, **Catat keluar**, **Pindah dana**, **Scan struk**; di bawahnya pintasan Riwayat/Budget/Laporan/Utang.
- "Top kategori" dan "Terakhir dicatat" ikut periode aktif — ketuk transaksi untuk edit.

## Navigasi bawah
Kapsul melayang `Riwayat · ( + ) · Scan`. Beranda adalah halaman induk (kembali lewat tombol back), Pengaturan lewat gear di header Beranda.

## Mencatat (tombol + tengah)
1. Pilih **Keluar** / **Masuk**.
2. Isi nominal (ketik angka saja — titik otomatis muncul, cth. ketik `25000` jadi `25.000`).
3. Pilih kategori (atau "+ Tambah kategori baru").
4. Catatan opsional, tanggal bisa diubah. **Default tanggal ikut periode yang sedang dilihat** — saat menjelajah kemarin/bulan lalu, transaksi tidak diam-diam masuk ke hari ini.
5. Simpan. Saldo & ringkasan langsung berubah.

> **Scan struk (HP Android/iOS):** ketuk ikon scan di kanan judul → pilih kamera/galeri → OCR jalan 100% di HP (tanpa internet) → nominal + tanggal + warung + saran kategori terisi otomatis. **Cek lagi sebelum Simpan** — hasil OCR bisa meleset di struk lusuh.

## Riwayat
- Ikut periode aktif dari Beranda; ganti periode langsung di switcher atas (tanpa kembali ke Beranda).
- Kolom cari untuk catatan, chip **Semua/Keluar/Masuk**, chip kategori untuk filter.
- Chip **Kalender** = grid total masuk/keluar per tanggal; ketuk tanggal → mode Harian. Satu-satunya pintu kalender (ikon di header sudah dihapus di v1.36.1).
- Ketuk baris untuk edit/hapus.

## Budget
- Satu budget = satu kategori + satu bulan. Contoh: Makan & Minum Rp1.500.000 untuk Oktober 2026.
- **Budget selalu dihitung per bulan**, tidak ikut switcher periode Harian/Mingguan/Tahunan (ada caption pengingatnya di layar).
- Bar hijau → oranye (≥80%) → merah + label LEWAT jika jebol.
- "Tambah / Ubah Budget" untuk menambah kategori lain atau mengubah batas.

## Laporan
- Grafik batang 6 bulan (hijau = masuk, merah = keluar).
- Ringkasan + pie + rincian pengeluaran per kategori mengikuti periode aktif (Harian/Mingguan/Bulanan/Tahunan); perbandingan memakai rentang sebelumnya yang setara.
- Tombol **Export PDF** mengikuti periode yang sedang dilihat (dulu selalu bulan berjalan). Nama file menyertakan periode, mis. `harian-20261021`.

## Utang (tab ke-5)
- **Utang** = aku pinjam (catat = saldo BERTAMBAH, tiap bayar = saldo berkurang).
- **Piutang** = aku meminjami (catat = saldo BERKURANG, tiap terima = saldo bertambah). Tiap aksi otomatis tercatat juga di Riwayat (label "Utang — Budi" / "Bayar utang — Budi") sehingga laporan & PDF ikut.
- Kartu ringkas di Beranda (sisa utang vs piutang) — ketuk **Kelola** untuk buka tab Utang. Kosong = kartu sembunyi.
- Bayar bisa dicicil berkali-kali; nominal tidak bisa melebihi sisa. Jatuh tempo opsional — yang lewat ditandai merah LEWAT. Lunas otomatis saat sisa 0.
- Ubah: nama/total/tanggal/tempo/catatan (tipe dikunci; total baru tidak boleh di bawah yang sudah dibayar). Hapus: beserta riwayat bayar + catatan transaksinya (konfirmasi dulu, tanpa undo).

## Pengaturan (ikon ⚙️ kanan atas Beranda)
Halaman hub berisi 4 grup — ketuk untuk buka sub-halaman masing-masing. Kolom cari di hub memfilter semua item; ketuk hasil untuk lompat ke sub-halamannya.
- **Tampilan:** tema Terang/Gelap/Ikuti HP, warna aksen (6 pilihan) atau ikuti wallpaper HP (Material You, Android 12+), hitam pekat (mode gelap), ukuran font, nominal ringkas (Rp1,5 jt).
  - *Isi Beranda:* ringkasan hari ini, ringkasan masuk-keluar, top kategori, terakhir dicatat (3/5/10).
  - *List & tanggal:* list rapat, tanggal relatif (Hari ini/Kemarin), ikon kategori on/off.
- **Saldo, Privasi & Pengingat:** sembunyikan saldo (hanya saldo / semua nominal), saldo awal, kunci aplikasi PIN/biometrik (aktif lagi otomatis saat app ditinggal ke background), pengingat harian.
- **Kelola:** kelola kategori (halaman sendiri: tambah/hapus), export CSV, backup database, restore (kuning: menimpa semua data), hapus semua data (merah, konfirmasi 2x ketik HAPUS).
  - **Export CSV**: membuat file `mywallet-<timestamp>.csv` (kolom: tanggal, tipe, kategori, nominal, catatan) lalu dibuka lewat share sheet.
  - **Backup database**: salinan konsisten `mywallet.sqlite` ke file pilihan.
  - **Restore database**: kembalikan dari file backup, lalu tutup total aplikasi + buka lagi.
  - **Hapus semua data**: reset total (konfirmasi 2x, ketik HAPUS), lalu restart aplikasi.
