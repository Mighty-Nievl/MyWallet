# 06 — Roadmap

Urut saran pengerjaan setelah MVP stabil dipakai 2–4 minggu.

## v1.1 — Privasi & kebiasaan ✅ (rilis 7 Okt 2026 sebagai v1.1.0)
- [x] Kunci aplikasi (PIN / biometrik) — privasi itu alasan #1 orang mau pakai pencatat lokal.
- [x] Pengingat harian mencatat (notifikasi lokal, `flutter_local_notifications`).
- [x] Saldo awal / koreksi saldo (masuk P0 Pengaturan).
- [x] Backup (file `.sqlite` via `VACUUM INTO` + restore + hapus semua data) — dimajukan dari v1.3 karena kritis untuk app offline.
- [x] Tema gelap/terang + sembunyikan saldo.
- [ ] Input cepat: parsing "makan 25 ribu" dari satu kolom.

## v1.2 — Tampilan full ✅ (rilis 7 Okt 2026 sebagai v1.2.0)
- [x] Warna aksen (6 pilihan) + Material You / dynamic_color.
- [x] Hitam pekat mode gelap, privacy semua nominal, nominal ringkas (Rp1,5 jt).
- [x] Kustom Beranda (ringkasan / top kategori / terakhir 3-5-10).
- [x] Overkill: ukuran font, list rapat, tanggal relatif, ikon kategori on/off.

## v1.3 — Pengaturan rapi + ringkasan harian ✅ (rilis 7 Okt 2026 sebagai v1.3.0)
- [x] Restruktur Pengaturan: kolom cari, 4 grup (Tampilan / Saldo & Privasi / Kelola / Tentang), Isi Beranda jadi sub-bagian, Kelola kategori halaman sendiri, hirarki Data, Tentang tap-to-copy + changelog.
- [x] Ringkasan harian di Beranda (masuk / keluar / selisih hari ini, ikut privacy + nominal ringkas, toggle di Isi Beranda).

## v1.4 — Uang lebih terkontrol
- [ ] Multi-dompet (Tunai / Bank / E-wallet) + transfer antar dompet.
- [ ] Transaksi berulang (langganan bulanan otomatis tercatat).

## v1.4 — Data aman & berguna
- [ ] Rencana menabung / target (sinking fund).
- [ ] Insight sederhana: "pengeluaran makan naik 20% vs bulan lalu".

## Nanti / butuh riset
- Scan struk (OCR) — butuh ML Kit / layanan OCR.
- Sinkronisasi antar-HP / cloud — mengubah asumsi offline-first, desain dulu di [[02-Arsitektur]].
- Export PDF laporan bulanan.

## Catatan keputusan
Arsitektur saat ini (Drift + Riverpod stream) sudah cukup sampai v1.2. Multi-dompet = tambah tabel `wallets` + kolom `walletId` di transactions + migrasi schema v1→v2.
