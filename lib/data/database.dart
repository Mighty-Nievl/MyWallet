import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// Database lokal MyWallet (SQLite via Drift).
/// Offline-first: seluruh data tersimpan di file `mywallet.sqlite` di HP.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'mywallet.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Categories, Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  /// [executor] opsional agar bisa di-test in-memory
  /// (`NativeDatabase.memory()`) — default tetap file HP.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed kategori bawaan.
          for (final c in defaultCategories) {
            await into(categories).insert(
              CategoriesCompanion.insert(
                name: c['name'] as String,
                icon: Value(c['icon'] as String),
                isExpense: Value(c['isExpense'] as bool),
              ),
            );
          }
        },
      );

  // ---------- Query ringkas ----------

  /// Saldo = total pemasukan − total pengeluaran.
  Future<int> getBalance() async {
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 0',
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 1',
      readsFrom: {transactions},
    ).getSingle();
    return (inRow.read<int>('s')) - (outRow.read<int>('s'));
  }

  /// Total pemasukan & pengeluaran dalam rentang tanggal.
  Future<(int, int)> getTotals(DateTime from, DateTime to) async {
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 0 AND date BETWEEN ? AND ?',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 1 AND date BETWEEN ? AND ?',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {transactions},
    ).getSingle();
    return (inRow.read<int>('s'), outRow.read<int>('s'));
  }

  /// Riwayat transaksi + nama kategori, terbaru dulu.
  Stream<List<TxWithCategory>> watchHistory({
    int? categoryId,
    bool? isExpense,
    String? keyword,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) {
    final where = <String>['1=1'];
    final vars = <Variable>[];
    if (categoryId != null) {
      where.add('t.category_id = ?');
      vars.add(Variable.withInt(categoryId));
    }
    if (isExpense != null) {
      where.add('t.is_expense = ?');
      vars.add(Variable.withBool(isExpense));
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('t.note LIKE ?');
      vars.add(Variable.withString('%${keyword.trim()}%'));
    }
    if (from != null) {
      where.add('t.date >= ?');
      vars.add(Variable.withDateTime(from));
    }
    if (to != null) {
      where.add('t.date <= ?');
      vars.add(Variable.withDateTime(to));
    }
    final query = customSelect(
      'SELECT t.*, c.name AS cat_name, c.icon AS cat_icon '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE ${where.join(' AND ')} '
      'ORDER BY t.date DESC, t.id DESC LIMIT $limit OFFSET $offset',
      variables: vars,
      readsFrom: {transactions, categories},
    );
    return query.watch().map((rows) => rows.map(TxWithCategory.fromRow).toList());
  }

  /// Ringkasan pengeluaran per kategori dalam rentang tanggal.
  Future<List<CategoryTotal>> totalsByCategory(
      DateTime from, DateTime to, bool expense) async {
    final rows = await customSelect(
      'SELECT c.id AS cid, c.name AS cname, c.icon AS cicon, '
      'COALESCE(SUM(t.amount),0) AS total '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.is_expense = ? AND t.date BETWEEN ? AND ? '
      'GROUP BY c.id, c.name, c.icon ORDER BY total DESC',
      variables: [
        Variable.withBool(expense),
        Variable.withDateTime(from),
        Variable.withDateTime(to),
      ],
      readsFrom: {transactions, categories},
    ).get();
    return rows.map(CategoryTotal.fromRow).toList();
  }
}

/// Satu baris transaksi + info kategori (hasil join).
class TxWithCategory {
  TxWithCategory({
    required this.id,
    required this.amount,
    required this.isExpense,
    required this.categoryId,
    required this.date,
    required this.note,
    this.catName,
    this.catIcon,
  });

  factory TxWithCategory.fromRow(QueryRow row) => TxWithCategory(
        id: row.read<int>('id'),
        amount: row.read<int>('amount'),
        isExpense: row.read<bool>('is_expense'),
        categoryId: row.readNullable<int>('category_id'),
        date: row.read<DateTime>('date'),
        note: row.read<String>('note'),
        catName: row.readNullable<String>('cat_name'),
        catIcon: row.readNullable<String>('cat_icon'),
      );

  final int id;
  final int amount;
  final bool isExpense;
  final int? categoryId;
  final DateTime date;
  final String note;
  final String? catName;
  final String? catIcon;
}

/// Total nominal per kategori.
class CategoryTotal {
  CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.total,
  });

  factory CategoryTotal.fromRow(QueryRow row) => CategoryTotal(
        categoryId: row.readNullable<int>('cid'),
        name: row.readNullable<String>('cname') ?? 'Tanpa kategori',
        icon: row.readNullable<String>('cicon') ?? '📦',
        total: row.read<int>('total'),
      );

  final int? categoryId;
  final String name;
  final String icon;
  final int total;
}
