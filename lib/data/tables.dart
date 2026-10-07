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
