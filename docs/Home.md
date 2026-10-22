# MyWallet — Vault Dokumentasi

> Buka folder `docs/` ini sebagai vault di Obsidian (Open folder as vault).

## Mulai dari sini

1. [[01-Visi-dan-Ruang-Lingkup]] — kenapa aplikasi ini dibuat, untuk siapa, fitur MVP.
2. [[02-Arsitektur]] — stack Flutter, struktur folder, alur data.
3. [[03-Skema-Database]] — tabel SQLite (categories, transactions, budgets).
4. [[04-Panduan-Build]] — cara build & install APK di HP.
5. [[05-Panduan-Pakai]] — cara memakai aplikasi sehari-hari.
6. [[06-Roadmap]] — ide fitur lanjutan.
7. [[07-Rilis-dan-Obtainium]] — signing, rilis GitHub, install via Obtainium.
8. [[08-Karakteristik-Tampilan]] — identitas visual (mesh, floating, pill, kartu).

## Fakta kunci

- **Platform:** Flutter (Android utama, Windows untuk dev) · `com.rezal.mywallet`
- **Penyimpanan:** 100% lokal, SQLite via Drift — tanpa login, tanpa server.
- **State:** flutter_riverpod 3.x (`StreamProvider` auto-refresh, `StateProvider` via `legacy.dart`).
- **File DB:** `mywallet.sqlite` di folder dokumen aplikasi.
- **Status:** v1.37.0 — Beranda fokus data: periode tepat di atas kartu arus kas, transaksi terakhir naik sebelum kategori, menu ringkas 4 pintasan unik, tap kartu Pemasukan/Pengeluaran membuka Riwayat terfilter; Kelola dompet jadi tombol terpisah.

## Peta kode

- `lib/main.dart` — entry point (`ProviderScope` + `MyWalletApp` + pulihkan jadwal pengingat)
- `lib/ui/` — tema + design tokens (`design/`: warna/spacing/radius/tipografi/gradien/shadow) + komponen (`components/`: kartu, section, ikon kategori, header, month-nav, progress, empty-state, mesh-gradient), shell navigasi custom MyWallet, 12 layar (home + tx_form + history + budget + reports baru STEP 1-3, settings hub + 4 sub-halaman, categories, lock), widget, format rupiah/tanggal + formatter input nominal
- `lib/data/` — `tables.dart` (skema), `database.dart` (query), `providers.dart`, `actions.dart`, `settings.dart` (semua pengaturan + providers tampilan), `lock_service.dart` (PIN/biometrik), `reminder_service.dart` (notifikasi harian), `backup_service.dart` (backup/restore/wipe)
- `test/` — test helper format (27 test) + test CRUD budget (6 test, db in-memory)
