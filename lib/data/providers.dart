import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'database.dart';

/// Provider database (satu instance untuk seluruh aplikasi).
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Stream semua kategori (abjad).
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.categories)
        ..orderBy([
          (t) => OrderingTerm.asc(t.isExpense),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();
});

/// Kategori pengeluaran saja (untuk form & budget).
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.categories)
        ..where((t) => t.isExpense.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
});

/// Kategori pemasukan saja.
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.categories)
        ..where((t) => t.isExpense.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
});

/// Saldo saat ini (reaktif: ikut berubah tiap ada transaksi baru).
final balanceProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getBalance());
});

/// Bulan yang sedang dilihat (format "yyyy-MM"). Bisa diubah dari UI.
final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// Batas awal-akhir bulan yang dipilih.
final monthRangeProvider = Provider<(DateTime, DateTime)>((ref) {
  final parts = ref.watch(selectedMonthProvider).split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final from = DateTime(y, m, 1);
  final to = DateTime(y, m + 1, 1).subtract(const Duration(milliseconds: 1));
  return (from, to);
});

/// Total (pemasukan, pengeluaran) bulan yang dipilih. Auto-refresh tiap ada perubahan.
final monthTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  // Dengarkan tabel transaksi + bulan aktif; hitung ulang tiap ada perubahan.
  final (from, to) = ref.watch(monthRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to));
});

/// Ringkasan pengeluaran per kategori bulan yang dipilih.
final monthExpenseByCategoryProvider =
    StreamProvider<List<CategoryTotal>>((ref) {
  final db = ref.watch(dbProvider);
  final (from, to) = ref.watch(monthRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.totalsByCategory(from, to, true));
});

/// Filter riwayat (diubah dari layar Riwayat).
class HistoryFilter {
  const HistoryFilter({this.categoryId, this.isExpense, this.keyword = ''});
  final int? categoryId;
  final bool? isExpense;
  final String keyword;
}

final historyFilterProvider =
    StateProvider<HistoryFilter>((ref) => const HistoryFilter());

/// Stream riwayat sesuai filter aktif + bulan yang dipilih.
final historyProvider = StreamProvider<List<TxWithCategory>>((ref) {
  final db = ref.watch(dbProvider);
  final f = ref.watch(historyFilterProvider);
  final (from, to) = ref.watch(monthRangeProvider);
  return db.watchHistory(
    categoryId: f.categoryId,
    isExpense: f.isExpense,
    keyword: f.keyword,
    from: from,
    to: to,
  );
});

/// Stream budget bulan yang dipilih + total terpakai per kategori.
final budgetsProvider =
    StreamProvider<List<({Budget budget, String name, String icon, int spent})>>(
        (ref) {
  final db = ref.watch(dbProvider);
  final month = ref.watch(selectedMonthProvider);
  final result = db
      .select(db.transactions)
      .watch()
      .asyncMap((_) async {
    final (from, to) = ref.read(monthRangeProvider);
    final rows = await (db.select(db.budgets)
          ..where((b) => b.month.equals(month)))
        .get();
    final out = <({Budget budget, String name, String icon, int spent})>[];
    for (final b in rows) {
      final cat = await (db.select(db.categories)
            ..where((c) => c.id.equals(b.categoryId)))
          .getSingleOrNull();
      final spentRows = await db.customSelect(
        'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
        'WHERE is_expense = 1 AND category_id = ? AND date BETWEEN ? AND ?',
        variables: [
          Variable.withInt(b.categoryId),
          Variable.withDateTime(from),
          Variable.withDateTime(to),
        ],
        readsFrom: {db.transactions},
      ).getSingle();
      out.add((
        budget: b,
        name: cat?.name ?? '?',
        icon: cat?.icon ?? '📦',
        spent: spentRows.read<int>('s'),
      ));
    }
    return out;
  });
  return result;
});
