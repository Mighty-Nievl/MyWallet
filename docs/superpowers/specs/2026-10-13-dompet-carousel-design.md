# Spec: Carousel Kartu Dompet (ganti hero + chip) + Reorder di Kelola

Tanggal: 13 Okt 2026. Target rilis: v1.29.0 (v1.28.0 dipakai sesi lain: identitas visual mesh).

## 1. Masalah

Hero Beranda (`balanceProvider` = gabungan SEMUA dompet) tidak mengikuti
chip dompet (`selectedAccountProvider` — hanya dibaca provider di bawah
hero). Efek: chip bilang "Utama", kartu bilang angka gabungan tanpa label
nama dompet. Pengguna bingung angka milik siapa.

## 2. Keputusan

- Q1 → **B**: kartu "Semua"/total gabungan DIBUANG dari Beranda. Murni
  kartu per-dompet. Total gabungan tetap bisa dilihat di Laporan.
- Carousel → **slider** (`PageView` + dots indikator). Kartu tampil =
  dompet aktif = filter konten bawah.
- Q2 → **A**: reorder via drag di layar Kelola (`ReorderableListView`),
  tersimpan ke kolom `sortOrder` existing. Carousel Beranda ikut urutan.
  Swipe dan reorder tidak berebut gestur (gestur horizontal tunggal).
- Opsi → **Opsi 1**: carousel gantikan hero + chip SEKALIGUS. Opsi 2
  (carousel + chip) ditolak — dua kontrol satu state, redundan.

## 3. Section 1 — Carousel kartu dompet

- `PageView` di slot `home:hero-slot`; strip chip `home:accounts`
  DIHAPUS dari Beranda.
- Satu halaman = satu kartu: label nama dompet kecil di atas, saldo 48px,
  CTA `+ Catat keluar` penuh-lebar (layout dalam kartu = hero sekarang +
  label nama). Di bawah carousel: dots indikator + tombol teks kecil
  "Kelola dompet" → layar Kelola.
- State dua arah: halaman tampil ↔ `selectedAccountProvider`. Geser kartu
  = ganti filter = konten bawah ikut (pengeluaran, riwayat).
- 1 dompet: dots disembunyikan. Semua diarsip: empty-state + tombol
  Kelola (tidak crash).
- Data tiap kartu: `accountBalanceProvider(id)` EXISTING — tanpa provider
  saldo baru. Privacy mata ikut pola hero. Nama panjang → ellipsis.
- Konsekuensi eksplisit: angka gabungan hilang dari Beranda; user lama
  melihat angka satu dompet, bukan total. Saldo awal Settings tetap ada
  di Pengaturan sebagai data (tak tampil di Beranda).

## 4. Section 2 — Reorder di Kelola

- Daftar dompet di Kelola → `ReorderableListView`, handle drag di kanan
  tiap baris. Drop = langsung tulis `sortOrder` ke DB (tanpa tombol
  Simpan). Tanpa migrasi skema (`sortOrder` sudah ada).
- `accountsProvider` sudah urut `sortOrder` → nama → carousel otomatis
  ikut urutan baru.
- Arsip: tetap sembunyi dari carousel; tampil di Kelola berpenanda,
  terkunci di bawah (tidak ikut reorder).
- Tak berubah: tambah/hapus/ganti-nama (kontrak v1.25), sync `sortOrder`
  ikut aturan sync akun existing.

## 5. Section 3 — Testing + verifikasi

Regression test baru (pola existing: pump manual, `_flushDriftCloseTimer`,
tanpa `pumpAndSettle`):

1. N dompet → N kartu; dots muncul bila >1, sembunyi bila 1.
2. Geser kartu → `selectedAccountProvider` berubah → konten bawah ikut.
3. CTA di kartu kedua → form catat terisi dompet kedua.
4. Reorder di Kelola → `sortOrder` tersimpan → carousel ikut urutan.
5. Absence: chip `Semua` + hero gabungan tidak ada.

Verifikasi ship: analyze + full suite hijau, golden regen (hero berubah
total → golden lama basi), vision light + dark, changelog + docs +
commit + tag + CI Published (autopilot).

## 6. Non-goals

- Long-press reorder di Beranda (konflik scroll vertikal).
- Total gabungan sebagai kartu khusus di carousel.
- Ubah rumus saldo (`openingBalance` vs saldo awal Settings).
- Ubah kontrak hapus dompet / arsip / sync.
