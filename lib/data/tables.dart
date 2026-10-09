import 'package:drift/drift.dart';

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
}
