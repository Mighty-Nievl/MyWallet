import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'database.dart';
import 'settings.dart';

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
/// = saldo awal (pengaturan) + total transaksi.
final balanceProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  final start = ref.watch(startingBalanceProvider).value ?? 0;
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) async => start + await db.getBalance());
});

/// Bulan yang sedang dilihat (format "yyyy-MM"). Bisa diubah dari UI.
final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// Batas awal-akhir sebuah kunci bulan "yyyy-MM".
/// Fungsi murni agar bisa dipakai provider maupun [fetchBudgets].
(DateTime, DateTime) monthRangeOf(String monthKey) {
  final parts = monthKey.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final from = DateTime(y, m, 1);
  final to = DateTime(y, m + 1, 1).subtract(const Duration(milliseconds: 1));
  return (from, to);
}

/// Batas awal-akhir bulan yang dipilih.
final monthRangeProvider = Provider<(DateTime, DateTime)>((ref) {
  return monthRangeOf(ref.watch(selectedMonthProvider));
});

/// Total (pemasukan, pengeluaran) HARI INI. Auto-refresh tiap ada perubahan.
/// Batas: 00:00:00 hari ini s/d 23:59:59 hari ini (waktu lokal HP).
final dayTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to));
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
/// Trigger dengarkan budgets + transactions (fix v1.7.2) —
/// hitung beratnya di [fetchBudgets] (fungsi murni, testable).
final budgetsProvider =
    StreamProvider<List<({Budget budget, String name, String icon, int spent})>>(
        (ref) {
  final db = ref.watch(dbProvider);
  final month = ref.watch(selectedMonthProvider);
  final (from, to) = ref.watch(monthRangeProvider);
  final result = db
      .customSelect('SELECT 1', readsFrom: {db.budgets, db.transactions})
      .watch()
      .asyncMap((_) => fetchBudgets(db, month: month, from: from, to: to));
  return result;
});

/// Ambil budget + spent per kategori, urutan stabil abjad.
/// Fungsi murni (tanpa ref) agar bisa di-test langsung dengan db in-memory.
Future<List<({Budget budget, String name, String icon, int spent})>>
    fetchBudgets(
  AppDatabase db, {
  required String month,
  required DateTime from,
  required DateTime to,
}) async {
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
  // Urutan stabil abjad — posisi item tidak lompat tiap refresh.
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

// ---------- Utang-piutang (v1.15) ----------

/// Satu utang + progress bayar (paid dihitung dari cicilan).
/// Lunas = paid >= total (tidak disimpan agar tidak basi).
typedef DebtEntry = ({
  Debt debt,
  int paid,
  int remaining,
  bool done,
});

int _debtRemain(int total, int paid) => total - paid;

/// Semua utang + progress, urutan stabil: belum lunas dulu (jatuh tempo
/// terdekat), lalu lunas abjad. Fungsi murni (testable in-memory).
Future<List<DebtEntry>> fetchDebts(AppDatabase db) async {
  final debts =
      await (db.select(db.debts)..orderBy([(d) => OrderingTerm.asc(d.name)]))
          .get();
  final out = <DebtEntry>[];
  for (final d in debts) {
    final row = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) AS s FROM debt_payments WHERE debt_id = ?',
      variables: [Variable.withInt(d.id)],
      readsFrom: {db.debtPayments},
    ).getSingle();
    final paid = row.read<int>('s');
    out.add((
      debt: d,
      paid: paid,
      remaining: _debtRemain(d.total, paid),
      done: paid >= d.total,
    ));
  }
  out.sort((a, b) {
    // Belum lunas dulu.
    if (a.done != b.done) return a.done ? 1 : -1;
    if (!a.done) {
      // Sama-sama aktif: yang ada jatuh tempo + paling dekat dulu.
      final ad = a.debt.dueDate;
      final bd = b.debt.dueDate;
      if (ad != null && bd != null) {
        final c = ad.compareTo(bd);
        if (c != 0) return c;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }
    }
    return a.debt.name.compareTo(b.debt.name);
  });
  return out;
}

/// Stream utang + progress. Trigger dengarkan debts + debt_payments +
/// transactions (cermin ikut berubah tiap aksi).
final debtsProvider = StreamProvider<List<DebtEntry>>((ref) {
  final db = ref.watch(dbProvider);
  return db
      .customSelect('SELECT 1',
          readsFrom: {db.debts, db.debtPayments, db.transactions})
      .watch()
      .asyncMap((_) => fetchDebts(db));
});

/// Total sisa AKTIF: (utang belum dibayar) vs (piutang belum diterima).
/// Dipakai kartu ringkas Beranda. (sisaUtang, sisaPiutang).
final debtSummaryProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  return db
      .customSelect('SELECT 1',
          readsFrom: {db.debts, db.debtPayments, db.transactions})
      .watch()
      .asyncMap((_) async {
    final list = await fetchDebts(db);
    var utang = 0;
    var piutang = 0;
    for (final e in list) {
      if (e.done) continue;
      if (e.debt.isDebt) {
        utang += e.remaining;
      } else {
        piutang += e.remaining;
      }
    }
    return (utang, piutang);
  });
});

/// Cicilan satu utang, terbaru dulu.
Stream<List<DebtPayment>> watchDebtPayments(AppDatabase db, int debtId) {
  return (db.select(db.debtPayments)
        ..where((p) => p.debtId.equals(debtId))
        ..orderBy([(p) => OrderingTerm.desc(p.date)]))
      .watch();
}
