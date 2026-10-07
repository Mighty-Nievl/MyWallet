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

## Fakta kunci

- **Platform:** Flutter (Android utama, Windows untuk dev) · `com.nievl.mywallet`
- **Penyimpanan:** 100% lokal, SQLite via Drift — tanpa login, tanpa server.
- **State:** flutter_riverpod 3.x (`StreamProvider` auto-refresh, `StateProvider` via `legacy.dart`).
- **File DB:** `mywallet.sqlite` di folder dokumen aplikasi.
- **Status:** v1.2.1 — Seragamkan warna semantik ikut colorScheme (pemasukan/warning) + rapikan palet pie & border form · 23 test hijau.

## Peta kode

- `lib/main.dart` — entry point (`ProviderScope` + `MyWalletApp` + pulihkan jadwal pengingat)
- `lib/ui/` — tema, shell 4 tab + tombol + tengah, 7 layar (home, tx_form, history, budget, reports, settings, lock), widget, format rupiah/tanggal
- `lib/data/` — `tables.dart` (skema), `database.dart` (query), `providers.dart`, `actions.dart`, `settings.dart` (semua pengaturan + providers tampilan), `lock_service.dart` (PIN/biometrik), `reminder_service.dart` (notifikasi harian), `backup_service.dart` (backup/restore/wipe)
- `test/widget_test.dart` — test helper format (23 test)
