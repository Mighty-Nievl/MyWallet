# 03 — Skema Database

SQLite `mywallet.sqlite`, `schemaVersion = 1`. Seed 12 kategori saat database pertama dibuat.

## categories

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| name | TEXT | nama kategori |
| icon | TEXT, default `'📦'` | emoji |
| isExpense | BOOLEAN (int) | true = pengeluaran |

Seed bawaan — keluar: Makan & Minum 🍔, Transportasi 🛵, Belanja 🛍️, Tagihan 🧾, Kesehatan 💊, Hiburan 🎮, Pendidikan 📚, Lainnya 📦. Masuk: Gaji 💰, Bonus 🎁, Usaha 🏪, Lainnya (Masuk) 📥.

## transactions

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| amount | INTEGER | nominal rupiah (bulat, selalu positif; arah dari `isExpense`) |
| isExpense | BOOLEAN | true = keluar |
| categoryId | INTEGER NULL, FK → categories(id), ON DELETE SET NULL | boleh tanpa kategori |
| date | DATETIME | tanggal transaksi (bisa di-backdate) |
| note | TEXT, default `''` | catatan bebas |
| createdAt | DATETIME, default now | audit |

## budgets

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| categoryId | INTEGER, FK → categories(id), ON DELETE CASCADE | |
| `limit` | INTEGER | batas rupiah per bulan |
| month | TEXT | format `"yyyy-MM"`, unik per (categoryId, month) di level aplikasi (`upsertBudget`) |

## Query penting (`database.dart`)
- `getBalance()` — total masuk − total keluar (2x `COALESCE(SUM…)`).
- `getTotals(from, to)` — (masuk, keluar) dalam rentang.
- `watchHistory({categoryId, isExpense, keyword, limit, offset})` — join transaksi+kategori, `ORDER BY date DESC, id DESC`, stream.
- `totalsByCategory(from, to, expense)` — agregasi per kategori untuk dashboard & laporan.

## Migrasi
Belum ada migrasi (v1). Saat menambah kolom/tabel: naikkan `schemaVersion` dan tulis `onUpgrade` di `migration`, JANGAN `deleteAndRecreate` di produksi.
