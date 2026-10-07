# 06 — Roadmap

Urut saran pengerjaan setelah MVP stabil dipakai 2–4 minggu.

## v1.1 — Privasi & kebiasaan
- [ ] Kunci aplikasi (PIN / biometrik) — privasi itu alasan #1 orang mau pakai pencatat lokal.
- [ ] Pengingat harian mencatat (notifikasi lokal, `flutter_local_notifications`).
- [ ] Input cepat: parsing "makan 25 ribu" dari satu kolom.

## v1.2 — Uang lebih terkontrol
- [ ] Multi-dompet (Tunai / Bank / E-wallet) + transfer antar dompet.
- [ ] Transaksi berulang (langganan bulanan otomatis tercatat).
- [ ] Saldo awal / koreksi saldo.

## v1.3 — Data aman & berguna
- [ ] Backup otomatis (file `.sqlite` ke folder pilihan + restore).
- [ ] Rencana menabung / target (sinking fund).
- [ ] Insight sederhana: "pengeluaran makan naik 20% vs bulan lalu".

## Nanti / butuh riset
- Scan struk (OCR) — butuh ML Kit / layanan OCR.
- Sinkronisasi antar-HP / cloud — mengubah asumsi offline-first, desain dulu di [[02-Arsitektur]].
- Export PDF laporan bulanan.

## Catatan keputusan
Arsitektur saat ini (Drift + Riverpod stream) sudah cukup sampai v1.2. Multi-dompet = tambah tabel `wallets` + kolom `walletId` di transactions + migrasi schema v1→v2.
