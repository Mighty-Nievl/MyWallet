# 03 — Skema Database

SQLite `mywallet.sqlite`, `schemaVersion = 2` (v1.15: migrasi v1→v2 tambah 2 kolom + 2 tabel utang, data lama utuh). Seed 12 kategori saat database pertama dibuat.

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
| debtId | INTEGER NULL | v1.15: tautan utang (null = biasa). Terisi = transaksi CERMIN otomatis (lihat `debt_actions.dart`) |
| debtPaymentId | INTEGER NULL | v1.15: terisi = cermin cicilan ke-N |

## budgets

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| categoryId | INTEGER, FK → categories(id), ON DELETE CASCADE | |
| `limit` | INTEGER | batas rupiah per bulan |
| month | TEXT | format `"yyyy-MM"`, unik per (categoryId, month) di level aplikasi (`upsertBudget`) |

## debts (v1.15 — utang-piutang)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| name | TEXT | nama orang (cth. "Budi") |
| isDebt | BOOLEAN | true = UTANG (aku pinjam → catat = pemasukan, bayar = pengeluaran); false = PIUTANG (aku meminjami → catat = pengeluaran, terima = pemasukan) |
| total | INTEGER | pokok awal rupiah |
| date | DATETIME | tanggal catat |
| dueDate | DATETIME NULL | jatuh tempo opsional |
| note | TEXT, default `''` | catatan bebas |
| createdAt | DATETIME, default now | audit |

Status lunas TIDAK disimpan — dihitung (`paid >= total`) dari cicilan.

## debt_payments (v1.15 — cicilan)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| debtId | INTEGER, FK → debts(id), ON DELETE CASCADE | |
| amount | INTEGER | nominal cicilan rupiah |
| date | DATETIME | tanggal bayar/terima |
| note | TEXT, default `''` | catatan bebas |
| createdAt | DATETIME, default now | audit |

Semantik saldo: tiap catat/bayar menulis transaksi CERMIN ke `transactions` (flag `debtId`/`debtPaymentId`) — saldo, laporan, riwayat, PDF & CSV ikut otomatis tanpa ubah query lama. Jangan edit cermin dari form transaksi (nanti konsisten pecah); ubah/hapus lewat layar Utang.

## Query penting (`database.dart`)
- `getBalance()` — total masuk − total keluar (2x `COALESCE(SUM…)`).
- `getTotals(from, to)` — (masuk, keluar) dalam rentang.
- `watchHistory({categoryId, isExpense, keyword, limit, offset})` — join transaksi+kategori, `ORDER BY date DESC, id DESC`, stream.
- `totalsByCategory(from, to, expense)` — agregasi per kategori untuk dashboard & laporan.

## Migrasi
- v1 → v2 (v1.15, utang-piutang): tambah kolom `transactions.debtId/debtPaymentId` (nullable) + tabel `debts` + `debt_payments`. `deleteDebt` hapus eksplisit berurutan (tidak ngandelin FK cascade — SQLite bisa pragma OFF).
- Saat menambah kolom/tabel berikutnya: naikkan `schemaVersion` dan tulis `onUpgrade` di `migration`, JANGAN `deleteAndRecreate` di produksi.
