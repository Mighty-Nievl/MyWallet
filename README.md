# MyWallet — Pencatat Keuangan Pribadi (Flutter, offline-first)

Aplikasi pencatat pemasukan & pengeluaran. Data **100% lokal** (SQLite via Drift) — tanpa login, tanpa server.

## Status: v1.2.1 ✅
- `flutter analyze` → No issues found · `flutter test` → 23/23 passed
- Warna semantik ikut colorScheme: pemasukan = `primary`, keluar = `error`, warning budget 80% = `tertiary` (dulu hijau/oranye fix)
- Palet pie fix 6 warna tanpa hijau (biar tidak ambigu dengan pemasukan/aksen)
- Bottom bar [home] [history] [+] [budget] [laporan] · settings di kanan atas Beranda
- Catat / edit / hapus transaksi · kategori custom · riwayat + filter
- Budget bulanan per kategori · laporan 6 bulan + pie · export CSV
- Tampilan full: tema, 6 warna aksen + Material You, hitam pekat, privacy semua nominal, nominal ringkas (Rp1,5 jt), font, kustom Beranda, list rapat, tanggal relatif, ikon on/off

## Teknologi
Flutter 3.44 · Dart 3.12 · Drift 2.35 (SQLite) · flutter_riverpod 3.4 · fl_chart · Material 3 · local_auth · flutter_secure_storage · flutter_local_notifications · file_picker

## Mulai cepat

```powershell
cd E:\Projects\MyWallet
flutter pub get
dart run build_runner build   # regenerasi database.g.dart
flutter analyze
flutter test
flutter build apk --debug     # APK: build\app\outputs\flutter-apk\app-debug.apk
flutter install                # ke HP yang tersambung
```

## Dokumentasi (vault Obsidian)
Buka folder `docs/` sebagai vault di Obsidian → mulai dari `docs/Home.md`:

- `01-Visi-dan-Ruang-Lingkup.md` — kenapa & apa isinya
- `02-Arsitektur.md` — stack, struktur folder, alur data
- `03-Skema-Database.md` — tabel categories / transactions / budgets
- `04-Panduan-Build.md` — cara build & install
- `05-Panduan-Pakai.md` — cara memakai aplikasi
- `06-Roadmap.md` — rencana fitur lanjutan

## Struktur kode

```
lib/
├── main.dart            # ProviderScope + MyWalletApp
├── data/                # tables, database (+ .g.dart codegen), providers, actions
├── ui/                  # app, theme, shell 5 tab, format, widgets, screens/
└── test/widget_test.dart# 12 unit test helper format
```
