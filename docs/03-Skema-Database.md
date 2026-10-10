# 03 — Skema Database

SQLite `mywallet.sqlite`, `schemaVersion = 3` (v1.16 Fase 0 sync-ready: 4 kolom meta di semua tabel + `categoryUuid` di transactions, migrasi v2→v3 aman + backfill otomatis; v1.15: migrasi v1→v2 tambah 2 kolom + 2 tabel utang, data lama utuh). Seed 12 kategori saat database pertama dibuat.

Kolom sync di SEMUA tabel (`categories`, `transactions`, `budgets`, `debts`, `debt_payments`):

| Kolom | Tipe | Keterangan |
|---|---|---|
| uuid | TEXT NULL, auto UUID v4 via `clientDefault` | identitas global antar-HP (unik logis, tanpa UNIQUE SQL — SQLite melarang ADD COLUMN ber-constraint UNIQUE) |
| updatedAt | DATETIME NULL, auto jam tulis via `clientDefault` + bump manual tiap update | jejak last-write-wins per-baris (Fase 2) |
| deletedAt | DATETIME NULL | soft-delete: null = hidup; query saldo/laporan/riwayat/budget/utang memfilter `IS NULL` (kontrak Fase 2, Fase 0 belum ada yang mengisi) |
| householdId | TEXT NULL | null = pribadi; terisi = milik rumah tangga (Fase 1) |

Util: `lib/data/sync_meta.dart` (`newSyncUuid()`, `syncNow()`, `syncUuidPattern`). Backfill migrasi: `AppDatabase.backfillSyncMeta()` (public agar testable — uuid per baris, updatedAt = createdAt kecuali categories/budgets = jam migrasi, categoryUuid dari induk). Test: `test/sync_ready_test.dart` (9 kasus).

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
| categoryUuid | TEXT NULL | v1.16 Fase 0: pendamping categoryId untuk sync (kategori custom beda id per HP, uuid sama; dibackfill + ditulis actions) |

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
- v2 → v3 (v1.16 Fase 0, sync-ready): 4 kolom meta (`uuid/updatedAt/deletedAt/householdId`) di 5 tabel + `categoryUuid` di transactions + backfill (`backfillSyncMeta`: uuid v4 per baris, updatedAt = createdAt kecuali categories/budgets, categoryUuid dari induk). Semua nullable → data lama utuh. Tanpa network, offline 100% sama.
- v1 → v2 (v1.15, utang-piutang): tambah kolom `transactions.debtId/debtPaymentId` (nullable) + tabel `debts` + `debt_payments`. `deleteDebt` hapus eksplisit berurutan (tidak ngandelin FK cascade — SQLite bisa pragma OFF).
- Saat menambah kolom/tabel berikutnya: naikkan `schemaVersion` dan tulis `onUpgrade` di `migration`, JANGAN `deleteAndRecreate` di produksi.
