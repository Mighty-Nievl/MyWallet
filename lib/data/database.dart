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

@DriftDatabase(
  tables: [Categories, Transactions, Budgets, Debts, DebtPayments, Accounts],
)
class AppDatabase extends _$AppDatabase {
  /// [executor] opsional agar bisa di-test in-memory
  /// (`NativeDatabase.memory()`) — default tetap file HP.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

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
      // v3 → v4 (dompet ganda v1.25): tabel accounts + kolom
      // accountId/accountUuid/transferId di transactions, accountId di
      // debts + debtPayments. Semua nullable → data lama utuh; baris
      // lama jatuh ke dompet "Utama" via backfill di bawah.
      // CATATAN saldo awal: Settings starting_balance tinggal di
      // SharedPreferences (bukan SQLite) — migrasi tak bisa membacanya.
      // Ia dianggap milik gabungan saat runtime (balanceProvider),
      // BUKAN dipindah ke Utama.openingBalance di sini.
      if (from < 4) {
        await m.createTable(accounts);
        await m.addColumn(transactions, transactions.accountId);
        await m.addColumn(transactions, transactions.accountUuid);
        await m.addColumn(transactions, transactions.transferId);
        await m.addColumn(debts, debts.accountId);
        await m.addColumn(debtPayments, debtPayments.accountId);
        await backfillAccounts();
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
          await (update(categories)..where((c) => c.id.equals(r.id))).write(
            CategoriesCompanion(uuid: Value(u)),
          );
        } else if (r is Transaction) {
          await (update(transactions)..where((t) => t.id.equals(r.id))).write(
            TransactionsCompanion(uuid: Value(u)),
          );
        } else if (r is Budget) {
          await (update(budgets)..where((b) => b.id.equals(r.id))).write(
            BudgetsCompanion(uuid: Value(u)),
          );
        } else if (r is Debt) {
          await (update(debts)..where((d) => d.id.equals(r.id))).write(
            DebtsCompanion(uuid: Value(u)),
          );
        } else if (r is DebtPayment) {
          await (update(debtPayments)..where((p) => p.id.equals(r.id))).write(
            DebtPaymentsCompanion(uuid: Value(u)),
          );
        }
      }
    }

    // 2) updatedAt ← createdAt (3 tabel punya createdAt; categories +
    // budgets TIDAK → jam migrasi).
    final migNow = syncNow();
    for (final rows in [
      await (select(transactions)..where((t) => t.updatedAt.isNull())).get(),
      await (select(debts)..where((d) => d.updatedAt.isNull())).get(),
      await (select(debtPayments)..where((p) => p.updatedAt.isNull())).get(),
    ]) {
      for (final r in rows) {
        if (r is Transaction) {
          await (update(transactions)..where((t) => t.id.equals(r.id))).write(
            TransactionsCompanion(updatedAt: Value(r.createdAt)),
          );
        } else if (r is Debt) {
          await (update(debts)..where((d) => d.id.equals(r.id))).write(
            DebtsCompanion(updatedAt: Value(r.createdAt)),
          );
        } else if (r is DebtPayment) {
          await (update(debtPayments)..where((p) => p.id.equals(r.id))).write(
            DebtPaymentsCompanion(updatedAt: Value(r.createdAt)),
          );
        }
      }
    }
    // categories + budgets tak punya createdAt → jam migrasi.
    for (final c in await (select(
      categories,
    )..where((c) => c.updatedAt.isNull())).get()) {
      await (update(categories)..where((x) => x.id.equals(c.id))).write(
        CategoriesCompanion(updatedAt: Value(migNow)),
      );
    }
    for (final b in await (select(
      budgets,
    )..where((b) => b.updatedAt.isNull())).get()) {
      await (update(budgets)..where((x) => x.id.equals(b.id))).write(
        BudgetsCompanion(updatedAt: Value(migNow)),
      );
    }

    // 3) categoryUuid ← uuid kategori induk (transaksi berkategori lama).
    await customStatement(
      'UPDATE transactions SET category_uuid = '
      '(SELECT uuid FROM categories WHERE categories.id = '
      'transactions.category_id) '
      'WHERE category_id IS NOT NULL AND category_uuid IS NULL',
    );
  }

  /// Backfill dompet untuk baris lama (migrasi v3→v4).
  ///
  /// - Seed dompet "Utama" (id dinamis — JANGAN asumsikan 1).
  /// - SEMUA baris lama (account_id NULL) → Utama, di 3 tabel.
  /// - accountUuid ← uuid akun induk (cermin pola categoryUuid v2→v3).
  /// - uuid/updatedAt akun baru terisi via clientDefault saat seed;
  ///   backfillSyncMeta di bawah menutup bila ada yang null.
  ///
  /// Public (bukan private) agar bisa di-test langsung seperti
  /// `backfillSyncMeta` (lihat `test/sync_ready_test.dart`).
  Future<void> backfillAccounts() async {
    final existing = await (select(
      accounts,
    )..where((a) => a.name.equals('Utama'))).getSingleOrNull();
    final uid =
        existing?.id ??
        await into(accounts).insert(AccountsCompanion.insert(name: 'Utama'));
    await customStatement(
      'UPDATE transactions SET account_id = $uid WHERE account_id IS NULL',
    );
    await customStatement(
      'UPDATE debts SET account_id = $uid WHERE account_id IS NULL',
    );
    await customStatement(
      'UPDATE debt_payments SET account_id = $uid WHERE account_id IS NULL',
    );
    await customStatement(
      'UPDATE transactions SET account_uuid = '
      '(SELECT uuid FROM accounts WHERE accounts.id = '
      'transactions.account_id) '
      'WHERE account_id IS NOT NULL AND account_uuid IS NULL',
    );
    await backfillSyncMeta();
  }

  // ---------- Query ringkas ----------

  /// Saldo = total pemasukan − total pengeluaran.
  /// Baris terhapus-lembut (deletedAt, Fase 2) tidak dihitung — Fase 0
  /// belum ada yang mengisinya, jadi hasil identik dengan sebelumnya.
  ///
  /// v1.25 (dompet ganda): [accountId] null = gabungan (perilaku lama,
  /// nol drift); terisi = hanya dompet itu. Kaki transfer IKUT saldo
  /// (pergerakan dompet yang sah) — yang dikecualikan hanya agregat
  /// pemasukan/pengeluaran ([getTotals]/[totalsByCategory]).
  /// Baris account_id NULL (gaya-lama pra-backfill) hanya terlihat
  /// di gabungan — semua insert baru WAJIB isi accountId.
  Future<int> getBalance({int? accountId}) async {
    // Bound variable bila filter dompet aktif; int dari DB (bukan input
    // user) tapi tetap pakai binding — nol risiko injeksi + konsisten.
    final acctClause = accountId == null ? '' : ' AND account_id = ?';
    final acctVars = accountId == null
        ? const <Variable>[]
        : <Variable>[Variable.withInt(accountId)];
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 0 AND deleted_at IS NULL$acctClause',
      variables: acctVars,
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions WHERE is_expense = 1 AND deleted_at IS NULL$acctClause',
      variables: acctVars,
      readsFrom: {transactions},
    ).getSingle();
    return (inRow.read<int>('s')) - (outRow.read<int>('s'));
  }

  /// Total pemasukan & pengeluaran dalam rentang tanggal.
  ///
  /// v1.25: kaki transfer SELALU dikecualikan (`transfer_id IS NULL`) —
  /// pindah dompet bukan pemasukan/pengeluaran. Nol drift untuk data
  /// lama (kolom baru, semua NULL). [accountId] null = gabungan.
  Future<(int, int)> getTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) async {
    final acctClause = accountId == null ? '' : ' AND account_id = ?';
    final inVars = <Variable>[
      if (accountId != null) Variable.withInt(accountId),
      Variable.withDateTime(from),
      Variable.withDateTime(to),
    ];
    final inRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 0 AND deleted_at IS NULL AND transfer_id IS NULL$acctClause AND date BETWEEN ? AND ?',
      variables: inVars,
      readsFrom: {transactions},
    ).getSingle();
    final outRow = await customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
      'WHERE is_expense = 1 AND deleted_at IS NULL AND transfer_id IS NULL$acctClause AND date BETWEEN ? AND ?',
      variables: inVars,
      readsFrom: {transactions},
    ).getSingle();
    return (inRow.read<int>('s'), outRow.read<int>('s'));
  }

  /// Klausa WHERE + variabel untuk filter riwayat — SATU sumber untuk
  /// [watchHistory] + [watchHistoryCount] (v1.24.9: tak bisa drift).
  ({List<String> where, List<Variable> vars}) _historyFilterParts({
    int? categoryId,
    bool? isExpense,
    String? keyword,
    DateTime? from,
    DateTime? to,
    int? accountId,
  }) {
    final where = <String>['t.deleted_at IS NULL'];
    final vars = <Variable>[];
    if (categoryId != null) {
      where.add('t.category_id = ?');
      vars.add(Variable.withInt(categoryId));
    }
    // v1.25 (dompet ganda): SATU sumber untuk list + count (aturan
    // v1.24.9) — filter dompet di sini agar keduanya tak bisa drift.
    if (accountId != null) {
      where.add('t.account_id = ?');
      vars.add(Variable.withInt(accountId));
    }
    if (isExpense != null) {
      where.add('t.is_expense = ?');
      vars.add(Variable.withBool(isExpense));
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      // v1.24.9: search jujur — cari di catatan + nama kategori
      // (kritik L4: dulu cuma note LIKE, tx tanpa-note tak bisa ditemukan).
      // Nominal ikut bila keyword murni angka (cari '60' ketemu 60000).
      final k = keyword.trim();
      final amount = int.tryParse(k.replaceAll(RegExp(r'[^0-9]'), ''));
      if (amount != null && amount > 0) {
        where.add('(t.note LIKE ? OR c.name LIKE ? OR t.amount = ?)');
        vars.add(Variable.withString('%$k%'));
        vars.add(Variable.withString('%$k%'));
        vars.add(Variable.withInt(amount));
      } else {
        where.add('(t.note LIKE ? OR c.name LIKE ?)');
        vars.add(Variable.withString('%$k%'));
        vars.add(Variable.withString('%$k%'));
      }
    }
    if (from != null) {
      where.add('t.date >= ?');
      vars.add(Variable.withDateTime(from));
    }
    if (to != null) {
      where.add('t.date <= ?');
      vars.add(Variable.withDateTime(to));
    }
    return (where: where, vars: vars);
  }

  /// Riwayat transaksi + nama kategori, terbaru dulu.
  Stream<List<TxWithCategory>> watchHistory({
    int? categoryId,
    bool? isExpense,
    String? keyword,
    DateTime? from,
    DateTime? to,
    int? accountId,
    int limit = 100,
    int offset = 0,
  }) {
    final parts = _historyFilterParts(
      categoryId: categoryId,
      isExpense: isExpense,
      keyword: keyword,
      from: from,
      to: to,
      accountId: accountId,
    );
    final query = customSelect(
      // v1.30: ikut bawa nama dompet (label per-baris + judul jujur).
      'SELECT t.*, c.name AS cat_name, c.icon AS cat_icon, '
      'a.name AS account_name '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'LEFT JOIN accounts a ON a.id = t.account_id '
      'WHERE ${parts.where.join(' AND ')} '
      'ORDER BY t.date DESC, t.id DESC LIMIT $limit OFFSET $offset',
      variables: parts.vars,
      readsFrom: {transactions, categories, accounts},
    );
    return query.watch().map(
      (rows) => rows.map(TxWithCategory.fromRow).toList(),
    );
  }

  /// Jumlah TOTAL hasil filter aktif (tanpa limit) — pasangan jujur
  /// [watchHistory] (v1.24.9: strip "Menampilkan 100 dari N").
  Stream<int> watchHistoryCount({
    int? categoryId,
    bool? isExpense,
    String? keyword,
    DateTime? from,
    DateTime? to,
    int? accountId,
  }) {
    final parts = _historyFilterParts(
      categoryId: categoryId,
      isExpense: isExpense,
      keyword: keyword,
      from: from,
      to: to,
      accountId: accountId,
    );
    final query = customSelect(
      'SELECT COUNT(*) AS c '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE ${parts.where.join(' AND ')}',
      variables: parts.vars,
      readsFrom: {transactions, categories},
    );
    return query.watchSingle().map((row) => row.read<int>('c'));
  }

  /// Ringkasan pengeluaran per kategori dalam rentang tanggal.
  ///
  /// v1.25: kaki transfer dikecualikan (bukan pengeluaran kategori);
  /// [accountId] null = gabungan.
  Future<List<CategoryTotal>> totalsByCategory(
    DateTime from,
    DateTime to,
    bool expense, {
    int? accountId,
  }) async {
    final acctClause = accountId == null ? '' : ' AND t.account_id = ?';
    final vars = <Variable>[
      Variable.withBool(expense),
      if (accountId != null) Variable.withInt(accountId),
      Variable.withDateTime(from),
      Variable.withDateTime(to),
    ];
    final rows = await customSelect(
      'SELECT c.id AS cid, c.name AS cname, c.icon AS cicon, '
      'COALESCE(SUM(t.amount),0) AS total '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.is_expense = ? AND t.deleted_at IS NULL AND t.transfer_id IS NULL$acctClause AND t.date BETWEEN ? AND ? '
      'GROUP BY c.id, c.name, c.icon ORDER BY total DESC',
      variables: vars,
      readsFrom: {transactions, categories},
    ).get();
    return rows.map(CategoryTotal.fromRow).toList();
  }
}

/// Satu baris transaksi + info kategori + nama dompet (hasil join).
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
    this.accountName,
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
    // v1.30: null = tx lama pra-dompet / dompet terhapus → tile sembunyikan.
    accountName: row.readNullable<String>('account_name'),
  );

  final int id;
  final int amount;
  final bool isExpense;
  final int? categoryId;
  final DateTime date;
  final String note;
  final String? catName;
  final String? catIcon;
  final String? accountName;
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
