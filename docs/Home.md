# MyWallet — Vault Dokumentasi

> Buka folder `docs/` ini sebagai vault di Obsidian (Open folder as vault).

## Mulai dari sini

1. [[01-Visi-dan-Ruang-Lingkup]] — kenapa aplikasi ini dibuat, untuk siapa, fitur MVP.
2. [[02-Arsitektur]] — stack Flutter, struktur folder, alur data.
3. [[03-Skema-Database]] — tabel SQLite (categories, transactions, budgets).
4. [[04-Panduan-Build]] — cara build & install APK di HP.
5. [[05-Panduan-Pakai]] — cara memakai aplikasi sehari-hari.
6. [[06-Roadmap]] — ide fitur lanjutan.

## Fakta kunci

- **Platform:** Flutter (Android utama, Windows untuk dev) · `com.nievl.mywallet`
- **Penyimpanan:** 100% lokal, SQLite via Drift — tanpa login, tanpa server.
- **State:** flutter_riverpod 3.x (`StreamProvider` auto-refresh, `StateProvider` via `legacy.dart`).
- **File DB:** `mywallet.sqlite` di folder dokumen aplikasi.
- **Status:** MVP v1.0.0 — `flutter analyze` bersih, 12 unit test lolos, APK debug terbukti bisa di-build.

## Peta kode

- `lib/main.dart` — entry point (`ProviderScope` + `MyWalletApp`)
- `lib/ui/` — tema, shell 5 tab, 5 layar, widget, format rupiah/tanggal
- `lib/data/` — `tables.dart` (skema), `database.dart` (query), `providers.dart`, `actions.dart`
- `test/widget_test.dart` — test helper format
