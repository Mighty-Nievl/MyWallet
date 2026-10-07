# 02 — Arsitektur

## Stack
- **Flutter 3.44** (Dart 3.12) · Material 3 · `com.nievl.mywallet`
- **Drift 2.35** + `sqlite3_flutter_libs` → SQLite lokal (`mywallet.sqlite`)
- **flutter_riverpod 3.4** → state reaktif. Catatan penting: `StateProvider` di v3 pindah ke `package:flutter_riverpod/legacy.dart` — jangan lupa import itu kalau pakai `StateProvider`.
- **fl_chart** → grafik laporan · **shared_preferences** → pengaturan · **share_plus** (v12 API: `SharePlus.instance.share(ShareParams(...))`) + **csv** (v8 API: `Csv().encode(rows)`) → export CSV.
- Codegen: `build_runner` + `drift_dev` → `lib/data/database.g.dart` (jangan edit manual).

## Struktur folder

```
lib/
├── main.dart            # ProviderScope + MyWalletApp
├── data/
│   ├── tables.dart      # definisi tabel + seed kategori
│   ├── database.dart    # AppDatabase + query custom (saldo, total, riwayat, per-kategori)
│   ├── database.g.dart  # hasil codegen (jangan edit)
│   ├── providers.dart   # Riverpod: db, kategori, saldo, bulan, riwayat, budget
│   └── actions.dart     # fungsi tulis: tambah/edit/hapus transaksi, kategori, budget
└── ui/
    ├── app.dart         # MaterialApp + tema
    ├── app_theme.dart   # Material 3, seed hijau-dompet
    ├── shell.dart       # 5 tab + FAB "Catat"
    ├── format.dart      # formatRp, parseRp, formatDate, monthKey/Label/shift
    ├── widgets/tx_tile.dart
    └── screens/         # home, tx_form, history, budget, reports, settings
```

## Alur data
1. UI membaca **provider** (`watch`) → rebuild otomatis saat DB berubah (stream).
2. UI menulis lewat **actions** (`addTransaction`, `upsertBudget`, …) → Drift insert/update/delete.
3. Tidak ada repository layer terpisah — `database.dart` + `providers.dart` + `actions.dart` menjalankan peran itu, cukup untuk skala MVP.

## Konvensi
- Nominal = `int` rupiah (tanpa desimal), kolom `amount`.
- `isExpense`: `true` = keluar, `false` = masuk.
- Bulan = string `"yyyy-MM"` (`selectedMonthProvider`), rentang dihitung di `monthRangeProvider`.
- Kategori nullable di transaksi → tampil "Tanpa kategori".
