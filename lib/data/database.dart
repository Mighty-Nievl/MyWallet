import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'sync_meta.dart';

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

@DriftDatabase(tables: [Categories, Transactions, Budgets, Debts, DebtPayments])
class AppDatabase extends _$AppDatabase {
  /// [executor] opsional agar bisa di-test in-memory
  /// (`NativeDatabase.memory()`) — default tetap file HP.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
        onUpgrade: (m, from, to) async {
          // v1 → v2 (utang-piutang): 2 kolom tautan di transactions +
          // 2 tabel baru. Data lama aman (kolom nullable, tabel kosong).
          if (from < 2) {
            await m.addColumn(transactions, transactions.debtId);
            await m.addColumn(transactions, transactions.debtPaymentId);
            await m.createTable(debts);
            await m.createTable(debtPayments);
          }
          // v2 → v3 (sync-ready Fase 0): 4 kolom meta di SEMUA tabel +
          // categoryUuid di transactions. Semua nullable → data lama utuh.
          // Backfill via Dart (bukan SQL random): uuid v4 asli + updatedAt
          // = createdAt (budgets = jam migrasi) + categoryUuid dari induk.
          if (from < 3) {
            await m.addColumn(categories, categories.uuid);
            await m.addColumn(categories, categories.updatedAt);
            await m.addColumn(categories, categories.deletedAt);
            await m.addColumn(categories, categories.householdId);
            await m.addColumn(transactions, transactions.categoryUuid);
            await m.addColumn(transactions, transactions.uuid);
            await m.addColumn(transactions, transactions.updatedAt);
            await m.addColumn(transactions, transactions.deletedAt);
            await m.addColumn(transactions, transactions.householdId);
            await m.addColumn(budgets, budgets.uuid);
            await m.addColumn(budgets, budgets.updatedAt);
            await m.addColumn(budgets, budgets.deletedAt);
            await m.addColumn(budgets, budgets.householdId);
            await m.addColumn(debts, debts.uuid);
            await m.addColumn(debts, debts.updatedAt);
            await m.addColumn(debts, debts.deletedAt);
            await m.addColumn(debts, debts.householdId);
            await m.addColumn(debtPayments, debtPayments.uuid);
            await m.addColumn(debtPayments, debtPayments.updatedAt);
            await m.addColumn(debtPayments, debtPayments.deletedAt);
            await m.addColumn(debtPayments, debtPayments.householdId);
            await backfillSyncMeta();
          }
        },
      );

  /// Backfill kolom sync untuk baris lama (migrasi v2→v3).
  ///
  /// - uuid kosong → UUID v4 baru (unik per baris).
  /// - updatedAt kosong → createdAt (transactions/debts/debtPayments);
  ///   categories + budgets tak punya createdAt → jam migrasi.
  /// - transactions.categoryUuid ← uuid kategori induknya.
  ///
  /// Pakai typed API (bukan raw per-baris) kecuali join kategori —
  /// aman dari salah nama kolom snake_case + salah unit DateTime.
  ///
  /// Public (bukan private) agar bisa di-test langsung via
  /// `test/sync_ready_test.dart` dengan baris gaya-lama (uuid null).
  Future<void> backfillSyncMeta() async {
    // 1) uuid per baris (satu UUID per baris — jangan satu untuk semua).
    for (final rows in [
      await (select(categories)..where((c) => c.uuid.isNull())).get(),
      await (select(transactions)..where((t) => t.uuid.isNull())).get(),
      await (select(budgets)..where((b) => b.uuid.isNull())).get(),
      await (select(debts)..where((d) => d.uuid.isNull())).get(),
      await (select(debtPayments)..where((p) => p.uuid.isNull())).get(),
    ]) {
      for (final r in rows) {
        final u = newSyncUuid();
        if (r is Category) {
          await (update(categories)..where((c) => c.id.equals(r.id)))
              .write(CategoriesCompanion(uuid: Value(u)));
        } else if (r is Transaction) {
          await (update(transactions)..where((t) => t.id.equals(r.id)))
              .write(TransactionsCompanion(uuid: Value(u)));
        } else if (r is Budget) {
          await (update(budgets)..where((b) => b.id.equals(r.id)))
              .write(BudgetsCompanion(uuid: Value(u)));
        } else if (r is Debt) {
          await (update(debts)..where((d) => d.id.equals(r.id)))
              .write(DebtsCompanion(uuid: Value(u)));
        } else if (r is DebtPayment) {
          await (update(debtPayments)..where((p) => p.id.equals(r.id)))
              .write(DebtPaymentsCompanion(uuid: Value(u)));
        }
      }
    }

    // 2) updatedAt ← createdAt (3 tabel punya createdAt; categories +
    // budgets TIDAK → jam migrasi).
    final migNow = syncNow();
    for (final rows in [
      await (select(transactions)..where((t) => t.updatedAt.isNull())).get(),
      await (select(debts)..where((d) => d.updatedAt.isNull())).get(),
      await (select(debtPayments)
            ..where((p) => p.updatedAt.isNull()))
          .get(),
    ]) {
      for (final r in rows) {
        if (r is Transaction) {
          await (update(transactions)..where((t) => t.id.equals(r.id))).write(
              TransactionsCompanion(updatedAt: Value(r.createdAt)));
        } else if (r is Debt) {
          await (update(debts)..where((d) => d.id.equals(r.id)))
              .write(DebtsCompanion(updatedAt: Value(r.createdAt)));
        } else if (r is DebtPayment) {
          await (update(debtPayments)..where((p) => p.id.equals(r.id))).write(
              DebtPaymentsCompanion(updatedAt: Value(r.createdAt)));
        }
      }
    }
    // categories + budgets tak punya createdAt → jam migrasi.
    for (final c
        in await (select(categories)..where((c) => c.updatedAt.isNull()))
            .get()) {
      await (update(categories)..where((x) => x.id.equals(c.id)))
          .write(CategoriesCompanion(updatedAt: Value(migNow)));
    }
    for (final b
        in await (select(budgets)..where((b) => b.updatedAt.isNull())).get()) {
      await (update(budgets)..where((x) => x.id.equals(b.id)))
          .write(BudgetsCompanion(updatedAt: Value(migNow)));
    }

    // 3) categoryUuid ← uuid kategori induk (transaksi berkategori lama).
    await customStatement(
      'UPDATE transactions SET category_uuid = '
      '(SELECT uuid FROM categories WHERE categories.id = '
      'transactions.category_id) '
      'WHERE category_id IS NOT NULL AND category_uuid IS NULL',
    );
  }

  // ---------- Query ringkas ----------

  /// Saldo = total pemasukan − total pengeluaran.
  /// Baris terhapus-lembut (deletedAt, Fase 2) tidak dihitung — Fase 0
  /// belum ada yang mengisinya, jadi hasil identik dengan sebelumnya.
  Future<int> getBalance() async {
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 0 AND deleted_at IS NULL',
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 1 AND deleted_at IS NULL',
      readsFrom: {transactions},
    ).getSingle();
    return (inRow.read<int>('s')) - (outRow.read<int>('s'));
  }

  /// Total pemasukan & pengeluaran dalam rentang tanggal.
  Future<(int, int)> getTotals(DateTime from, DateTime to) async {
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 0 AND deleted_at IS NULL AND date BETWEEN ? AND ?',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 1 AND deleted_at IS NULL AND date BETWEEN ? AND ?',
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
    final where = <String>['t.deleted_at IS NULL'];
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
      'WHERE t.is_expense = ? AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ? '
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
