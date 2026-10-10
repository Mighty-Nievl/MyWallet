import 'package:drift/drift.dart';

import 'sync_meta.dart';

/// Kolom sync-ready (Fase 0, v1.16) — dipakai SEMUA tabel.
/// Mixin tidak bisa untuk Drift Table (kolom harus getter langsung),
/// jadi pola ini diulang per tabel (lihat catatan di tiap tabel):
/// - `uuid`: identitas global antar-HP (UUID v4, auto-generate).
///   UNIK secara logis (peluang tabrakan UUID v4 ~nol, sync engine
///   Fase 2 juga cek per uuid) — SENGAJA tanpa UNIQUE di SQL karena
///   SQLite melarang ADD COLUMN ber-constraint UNIQUE (migrasi v2→v3
///   gagal bila dipaksa). Nullable di SQL demi migrasi aman; app selalu
///   mengisi via clientDefault sehingga baris baru TIDAK PERNAH null.
/// - `updatedAt`: jejak tulis terakhir (last-write-wins per-baris, Fase 2).
/// - `deletedAt`: soft-delete (null = hidup). Fase 0 baru kolomnya;
///   delete fisik tetap (Fase 2 yang mengubah jadi soft).
/// - `householdId`: null = pribadi; terisi = milik rumah tangga (Fase 1).

/// Daftar kategori bawaan yang di-seed saat database pertama dibuat.
const defaultCategories = <Map<String, Object>>[
  // Pengeluaran
  {'name': 'Makan & Minum', 'icon': '🍔', 'isExpense': true},
  {'name': 'Transportasi', 'icon': '🛵', 'isExpense': true},
  {'name': 'Belanja', 'icon': '🛍️', 'isExpense': true},
  {'name': 'Tagihan', 'icon': '🧾', 'isExpense': true},
  {'name': 'Kesehatan', 'icon': '💊', 'isExpense': true},
  {'name': 'Hiburan', 'icon': '🎮', 'isExpense': true},
  {'name': 'Pendidikan', 'icon': '📚', 'isExpense': true},
  {'name': 'Lainnya', 'icon': '📦', 'isExpense': true},
  // Pemasukan
  {'name': 'Gaji', 'icon': '💰', 'isExpense': false},
  {'name': 'Bonus', 'icon': '🎁', 'isExpense': false},
  {'name': 'Usaha', 'icon': '🏪', 'isExpense': false},
  {'name': 'Lainnya (Masuk)', 'icon': '📥', 'isExpense': false},
];

/// Tabel kategori transaksi.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('📦'))();
  // 1 = pengeluaran, 0 = pemasukan (bool SQLite disimpan sebagai int).
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  // --- Sync-ready (lihat catatan file) ---
  TextColumn get uuid =>
      text().clientDefault(() => newSyncUuid()).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncNow()).nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
}

/// Tabel transaksi keuangan.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nominal dalam rupiah (bilangan bulat, tanpa desimal).
  IntColumn get amount => integer()();
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.setNull).nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Tautan utang-piutang (v1.15, skema v2). null = transaksi biasa.
  // debtId terisi = transaksi OTOMATIS dari manajer utang (awal/cicilan)
  // — lihat debt_actions.dart. debtPaymentId terisi = cicilan ke-N.
  // Sengaja TANPA references (int polos): sirkular FK debts↔transactions
  // dihindari + query lama (saldo/laporan/riwayat) tidak berubah —
  // pembersihan manual di deleteDebt/deleteDebtPayment.
  IntColumn get debtId => integer().nullable()();
  IntColumn get debtPaymentId => integer().nullable()();
  // Pendamping categoryId untuk sync antar-HP (Fase 2): kategori custom
  // punya id int beda per HP, uuid sama. Dibackfill dari kategori saat
  // migrasi v2→v3; ditulis tiap insert transaksi berkategori.
  TextColumn get categoryUuid => text().nullable()();
  // --- Sync-ready (lihat catatan file) ---
  TextColumn get uuid =>
      text().clientDefault(() => newSyncUuid()).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncNow()).nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
}

/// Tabel budget bulanan per kategori.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  // Batas dalam rupiah.
  IntColumn get limit => integer()();
  // Format: "2026-10" (tahun-bulan).
  TextColumn get month => text()();
  // --- Sync-ready (lihat catatan file) ---
  // Budgets tidak punya createdAt → backfill updatedAt = jam migrasi.
  TextColumn get uuid =>
      text().clientDefault(() => newSyncUuid()).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncNow()).nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
}

/// Utang-piutang (v1.15, skema v2).
///
/// - [isDebt] true = UTANG (aku pinjam → saldo +total saat dicatat,
///   tiap bayar = pengeluaran). false = PIUTANG (aku meminjami →
///   saldo −total saat dicatat, tiap terima = pemasukan).
/// - Status lunas TIDAK disimpan (dihitung: paid >= total) agar tidak basi.
/// - Tiap catat/bayar menulis transaksi CERMIN ke [Transactions]
///   (kolom debtId/debtPaymentId) supaya saldo + laporan + riwayat
///   otomatis ikut — itu inti opsi B.
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nama orang (cth. "Budi").
  TextColumn get name => text()();
  BoolColumn get isDebt => boolean().withDefault(const Constant(true))();
  // Pokok awal dalam rupiah.
  IntColumn get total => integer()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // --- Sync-ready (lihat catatan file) ---
  TextColumn get uuid =>
      text().clientDefault(() => newSyncUuid()).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncNow()).nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
}

/// Cicilan utang-piutang — bisa berkali-kali sampai lunas.
/// Sumber kebenaran progress (paid = SUM amount per debtId).
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId =>
      integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // --- Sync-ready (lihat catatan file) ---
  TextColumn get uuid =>
      text().clientDefault(() => newSyncUuid()).nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => syncNow()).nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get householdId => text().nullable()();
}
