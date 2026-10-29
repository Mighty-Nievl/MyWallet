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
9. [[09-Review-Beranda]] — arsip review UI/UX Beranda v1.36.2 + status tiap temuan di v1.38.0.
10. [[10-Jurnal-Rilis]] — kenapa tiap rilis ada, bukti CI-nya, dan keputusan yang masih menggantung.

## Fakta kunci

- **Platform:** Flutter (Android utama, Windows untuk dev) · `com.rezal.mywallet`
- **Penyimpanan:** 100% lokal, SQLite via Drift — tanpa login, tanpa server.
- **State:** flutter_riverpod 3.x (`StreamProvider` auto-refresh, `StateProvider` via `legacy.dart`).
- **File DB:** `mywallet.sqlite` di folder dokumen aplikasi; salinan otomatis di `backups/mywallet-auto-YYYYMMDD.sqlite` (satu file per hari, rotasi 5 hari, diperbarui tiap simpan/hapus — v1.41.0).
- **Status:** v1.43.0 — Pengaturan dirapikan: satu katalog setelan (31 entri) jadi sumber pencarian hub sekaligus filter tiap sub-halaman, jadi semua baris benar-benar bisa ditemukan; `SettingSwitch` + `SettingsScaffold` menghapus 526 baris duplikasi; export CSV pindah ke `ExportService` yang bisa dites; setelan "Ringkasan masuk / keluar" yang sudah yatim (tidak dibaca layar mana pun) dibuang. Sebelumnya: Beranda satu rail (isi kartu x=32, judul x=16) dengan ritme 24/32.

## Peta kode

- `lib/main.dart` — entry point (`ProviderScope` + `MyWalletApp` + pulihkan jadwal pengingat)
- `lib/ui/` — tema + design tokens (`design/`: warna/spacing/radius/tipografi/gradien/shadow) + komponen (`components/`: kartu, section, ikon kategori, header, month-nav, progress, empty-state, mesh-gradient), shell navigasi custom MyWallet, 12 layar (home + tx_form + history + budget + reports baru STEP 1-3, settings hub + 4 sub-halaman, categories, lock), widget, format rupiah/tanggal + formatter input nominal
- `lib/data/` — `tables.dart` (skema), `database.dart` (query), `providers.dart`, `actions.dart`, `settings.dart` (semua pengaturan + providers tampilan), `lock_service.dart` (PIN/biometrik), `reminder_service.dart` (notifikasi harian), `backup_service.dart` (backup/restore/wipe)
- `test/` — test helper format (27 test) + test CRUD budget (6 test, db in-memory)
