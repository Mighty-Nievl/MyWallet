import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'database.dart';
import 'period.dart';
import 'settings.dart';

/// Provider database (satu instance untuk seluruh aplikasi).
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Stream semua kategori (abjad). Sembunyikan yang terhapus-lembut.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.categories)
        ..where((t) => t.deletedAt.isNull())
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
        ..where((t) => t.isExpense.equals(true) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
});

/// Kategori pemasukan saja.
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.categories)
        ..where((t) => t.isExpense.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
});

/// Saldo saat ini (reaktif: ikut berubah tiap ada transaksi baru).
/// = saldo awal (pengaturan) + total transaksi.
///
/// v1.25 (dompet ganda): saldo awal (Settings) dianggap milik GABUNGAN
/// — ditambah SEKALI di sini, bukan per dompet (agar tak dobel-hitung).
/// Lihat [accountBalanceProvider] untuk saldo satu dompet.
final balanceProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  final start = ref.watch(startingBalanceProvider).value ?? 0;
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) async => start + await db.getBalance());
});

// ---------- Dompet ganda (v1.25) ----------

/// Dompet aktif: null = Semua (gabungan, perilaku lama = default).
/// Diubah dari pemilih dompet (Beranda, Fase 3 UI); dibaca SEMUA
/// provider ringkasan + riwayat di bawah.
final selectedAccountProvider = StateProvider<int?>((ref) => null);

/// Semua dompet non-arsip, urutan stabil sortOrder lalu nama.
/// Arsip disembunyikan (bukan dihapus — riwayatnya tetap di gabungan).
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.accounts)
        ..where((a) => a.isArchived.equals(false) & a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm.asc(a.sortOrder),
          (a) => OrderingTerm.asc(a.name),
        ]))
      .watch();
});

/// Dompet yang diarsipkan (v1.36.2) — pintu pulih, bukan jalan buntu.
final archivedAccountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.accounts)
        ..where((a) => a.isArchived.equals(true) & a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm.asc(a.sortOrder),
          (a) => OrderingTerm.asc(a.name),
        ]))
      .watch();
});

/// Saldo SATU dompet = openingBalance + SUM transaksinya.
/// BUKAN saldo awal Settings (itu milik gabungan, lihat [balanceProvider]).
final accountBalanceProvider = StreamProvider.family<int, int>((
  ref,
  accountId,
) {
  final db = ref.watch(dbProvider);
  return db.select(db.transactions).watch().asyncMap((_) async {
    final acc = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    return (acc?.openingBalance ?? 0) +
        await db.getBalance(accountId: accountId);
  });
});

/// Dompet default untuk insert baru: akun aktif bila dipilih, bila
/// "Semua" (null) = dompet non-arsip pertama (biasanya "Utama").
/// Fungsi murni (testable) — insert tanpa dompet eksplisit JANGAN
/// pernah NULL (baris NULL hilang dari filter dompet).
Future<int?> defaultAccountId(AppDatabase db, int? selected) async {
  if (selected != null) return selected;
  final first =
      await (db.select(db.accounts)
            ..where((a) => a.isArchived.equals(false) & a.deletedAt.isNull())
            ..orderBy([
              (a) => OrderingTerm.asc(a.sortOrder),
              (a) => OrderingTerm.asc(a.name),
            ])
            ..limit(1))
          .getSingleOrNull();
  return first?.id;
}

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

/// Periode analitik aktif (v1.35.0).
///
/// Sumber kebenaran BARU untuk Harian/Mingguan/Bulanan/Tahunan. `anchor`
/// dipisah dari `selectedMonthProvider` supaya menggeser bulan di Beranda
/// tidak merusak periode harian yang sedang dilihat — dua state ini
/// disinkronkan hanya saat user memilih "Bulanan" (lihat PeriodSwitcher).
final periodKindProvider = StateProvider<PeriodKind>(
  (ref) => PeriodKind.bulanan,
);

/// Tanggal acuan periode (dinormalisasi oleh [Period.of]).
final periodAnchorProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final activePeriodProvider = Provider<Period>((ref) {
  final kind = ref.watch(periodKindProvider);
  // Bulanan tetap bersumber dari selectedMonthProvider (sumber lama, dipakai
  // nav bulan, Riwayat, Budget, grafik 6 bulan) agar SATU kebenaran: tidak
  // mungkin layar bulanan menampilkan bulan yang berbeda dari Laporan.
  // Periode lain memakai periodAnchorProvider karena bulan tak bisa
  // mewakili "hari ini" atau "minggu ini".
  final anchor = kind == PeriodKind.bulanan
      ? _anchorOfMonthKey(ref.watch(selectedMonthProvider))
      : ref.watch(periodAnchorProvider);
  return Period.of(kind, anchor);
});

/// "2026-10" → 1 Oktober 2026 (fallback: hari ini bila kunci rusak).
DateTime _anchorOfMonthKey(String key) {
  final parts = key.split('-');
  final y = parts.length == 2 ? int.tryParse(parts[0]) : null;
  final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (y == null || m == null || m < 1 || m > 12) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }
  return DateTime(y, m, 1);
}

/// Rentang periode aktif — pengganti `monthRangeProvider` untuk layar yang
/// mengikuti switcher.
final periodRangeProvider = Provider<(DateTime, DateTime)>((ref) {
  return ref.watch(activePeriodProvider).range;
});

/// Total (masuk, keluar) pada periode aktif.
final periodTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(periodRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to, accountId: acct));
});

/// Total (masuk, keluar) periode SEBELUMNYA — pembanding delta.
final prevPeriodTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(activePeriodProvider).previous.range;
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to, accountId: acct));
});

/// Total (pemasukan, pengeluaran) HARI INI. Auto-refresh tiap ada perubahan.
/// Batas: 00:00:00 hari ini s/d 23:59:59 hari ini (waktu lokal HP).
final dayTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to, accountId: acct));
});

/// Total (pemasukan, pengeluaran) bulan yang dipilih. Auto-refresh tiap ada perubahan.
final monthTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  // Dengarkan tabel transaksi + bulan aktif; hitung ulang tiap ada perubahan.
  final (from, to) = ref.watch(monthRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to, accountId: acct));
});

/// Ringkasan pengeluaran per kategori bulan yang dipilih.
final monthExpenseByCategoryProvider = StreamProvider<List<CategoryTotal>>((
  ref,
) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(monthRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.totalsByCategory(from, to, true, accountId: acct));
});

/// Ringkasan pengeluaran per kategori pada PERIODE aktif (v1.35.0).
final periodExpenseByCategoryProvider = StreamProvider<List<CategoryTotal>>((
  ref,
) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(periodRangeProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.totalsByCategory(from, to, true, accountId: acct));
});

/// Total per hari untuk satu bulan kalender ("yyyy-MM").
///
/// v1.36.0: keluarga provider ini sengaja TIDAK mengikuti periode aktif —
/// kalender butuh seluruh bulan walau user sedang melihat minggu/tahun.
/// Filter dompet tetap ikut `selectedAccountProvider`.
final calendarDailyTotalsProvider =
    StreamProvider.family<Map<DateTime, (int, int)>, String>((ref, month) {
      final db = ref.watch(dbProvider);
      final acct = ref.watch(selectedAccountProvider);
      final (from, to) = monthRangeOf(month);
      return db
          .select(db.transactions)
          .watch()
          .asyncMap((_) => db.getDailyTotals(from, to, accountId: acct));
    });

/// Satu titik arus kas bulanan: kunci "yyyy-MM" + (masuk, keluar).
/// Dipakai grafik 6 bulan di Laporan — fungsi murni (testable).
typedef MonthFlow = ({String key, int masuk, int keluar});

/// 6 titik arus (5 bulan mundur + bulan dipilih), TANPA DateTime.now()
/// (v1.24.11: testable + ikut bulan yang user lihat, bukan bulan HP).
/// Fungsi murni (tanpa ref) agar bisa di-test langsung dengan db in-memory.
///
/// v1.25: [accountId] null = gabungan.
Future<List<MonthFlow>> fetchSixMonthFlow(
  AppDatabase db,
  String anchorKey, {
  int? accountId,
}) {
  final parts = anchorKey.split('-');
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = parts.length > 1
      ? int.tryParse(parts[1]) ?? DateTime.now().month
      : DateTime.now().month;
  return () async {
    final out = <MonthFlow>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(y, m - i, 1);
      final from = DateTime(d.year, d.month, 1);
      final to = DateTime(
        d.year,
        d.month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));
      final (masuk, keluar) = await db.getTotals(
        from,
        to,
        accountId: accountId,
      );
      out.add((
        key: '${d.year}-${d.month.toString().padLeft(2, '0')}',
        masuk: masuk,
        keluar: keluar,
      ));
    }
    return out;
  }();
}

/// Arus 6 bulan reaktif (v1.24.11): dengarkan transaksi + bulan aktif —
/// ganti `_SixMonthChart.FutureBuilder` manual (balapan future, tak
/// reaktif). Guard balapan GRATIS: provider hanya emit hasil query
/// milik bulan+data terakhir (Riverpod buang stream basi otomatis).
final sixMonthFlowProvider = StreamProvider<List<MonthFlow>>((ref) {
  final db = ref.watch(dbProvider);
  final anchor = ref.watch(selectedMonthProvider);
  final acct = ref.watch(selectedAccountProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => fetchSixMonthFlow(db, anchor, accountId: acct));
});

/// Total (masuk, keluar) bulan SEBELUM bulan dipilih — bahan strip
/// wawasan Laporan ("Keluar naik 12% vs Sep"). Fungsi murni via
/// [monthRangeOf] (tak ada DateTime.now, ikut bulan yang dilihat).
final prevMonthTotalsProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final anchor = ref.watch(selectedMonthProvider);
  final acct = ref.watch(selectedAccountProvider);
  final parts = anchor.split('-');
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = parts.length > 1
      ? int.tryParse(parts[1]) ?? DateTime.now().month
      : DateTime.now().month;
  final prev = DateTime(y, m - 1, 1);
  final (from, to) = monthRangeOf(
    '${prev.year}-${prev.month.toString().padLeft(2, '0')}',
  );
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => db.getTotals(from, to, accountId: acct));
});

/// Filter riwayat (diubah dari layar Riwayat).
class HistoryFilter {
  const HistoryFilter({this.categoryId, this.isExpense, this.keyword = ''});
  final int? categoryId;
  final bool? isExpense;
  final String keyword;
}

final historyFilterProvider = StateProvider<HistoryFilter>(
  (ref) => const HistoryFilter(),
);

/// Stream riwayat sesuai filter aktif + PERIODE yang dipilih (v1.36.0).
final historyProvider = StreamProvider<List<TxWithCategory>>((ref) {
  final db = ref.watch(dbProvider);
  final f = ref.watch(historyFilterProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(periodRangeProvider);
  return db.watchHistory(
    categoryId: f.categoryId,
    isExpense: f.isExpense,
    keyword: f.keyword,
    from: from,
    to: to,
    accountId: acct,
  );
});

/// Jumlah TOTAL hasil filter aktif (tanpa limit) — strip Riwayat jujur
/// soal limit (v1.24.9: "Menampilkan 100 dari N"). v1.36.0: ikut periode.
final historyCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  final f = ref.watch(historyFilterProvider);
  final acct = ref.watch(selectedAccountProvider);
  final (from, to) = ref.watch(periodRangeProvider);
  return db.watchHistoryCount(
    categoryId: f.categoryId,
    isExpense: f.isExpense,
    keyword: f.keyword,
    from: from,
    to: to,
    accountId: acct,
  );
});

/// Stream budget bulan yang dipilih + total terpakai per kategori.
/// Trigger dengarkan budgets + transactions (fix v1.7.2) —
/// hitung beratnya di [fetchBudgets] (fungsi murni, testable).
final budgetsProvider =
    StreamProvider<
      List<({Budget budget, String name, String icon, int spent})>
    >((ref) {
      final db = ref.watch(dbProvider);
      final month = ref.watch(selectedMonthProvider);
      final acct = ref.watch(selectedAccountProvider);
      final (from, to) = ref.watch(monthRangeProvider);
      final result = db
          .customSelect('SELECT 1', readsFrom: {db.budgets, db.transactions})
          .watch()
          .asyncMap(
            (_) => fetchBudgets(
              db,
              month: month,
              from: from,
              to: to,
              accountId: acct,
            ),
          );
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
  // v1.25 (dompet ganda): null = gabungan (perilaku lama); terisi =
  // spent hanya dari dompet itu. Budget sendiri tetap global (tanpa
  // kolom baru) — keputusan plan: global + filter spent.
  int? accountId,
}) async {
  final rows = await (db.select(
    db.budgets,
  )..where((b) => b.month.equals(month))).get();
  final out = <({Budget budget, String name, String icon, int spent})>[];
  for (final b in rows) {
    // Budget terhapus-lembut (Fase 2) disembunyikan.
    if (b.deletedAt != null) continue;
    final cat = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(b.categoryId))).getSingleOrNull();
    // Kategori terhapus-lembut → tampil sebagai '?' (baris budget
    // fisiknya masih ada di Fase 0).
    final catAlive = (cat == null || cat.deletedAt != null) ? null : cat;
    final spentRows = await db
        .customSelect(
          'SELECT COALESCE(SUM(amount),0) AS s FROM transactions '
          'WHERE is_expense = 1 AND deleted_at IS NULL AND transfer_id IS NULL'
          '${accountId == null ? '' : ' AND account_id = ?'}'
          ' AND category_id = ? AND date BETWEEN ? AND ?',
          variables: [
            if (accountId != null) Variable.withInt(accountId),
            Variable.withInt(b.categoryId),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {db.transactions},
        )
        .getSingle();
    out.add((
      budget: b,
      name: catAlive?.name ?? '?',
      icon: catAlive?.icon ?? '📦',
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
typedef DebtEntry = ({Debt debt, int paid, int remaining, bool done});

int _debtRemain(int total, int paid) => total - paid;

/// Semua utang + progress, urutan stabil: belum lunas dulu (jatuh tempo
/// terdekat), lalu lunas abjad. Fungsi murni (testable in-memory).
/// Baris terhapus-lembut disembunyikan (Fase 2 baru mengisinya).
///
/// v1.25 (dompet ganda): [accountId] null = semua (perilaku lama);
/// terisi = hanya utang milik dompet itu.
Future<List<DebtEntry>> fetchDebts(AppDatabase db, {int? accountId}) async {
  // accountId null = SEMUA (tanpa klausa akun; baris gaya-lama NULL
  // ikut). equalsNullable(null) → IS NULL itu SALAH di sini.
  final debts =
      await (db.select(db.debts)
            ..where(
              (d) => accountId == null
                  ? d.deletedAt.isNull()
                  : d.deletedAt.isNull() & d.accountId.equals(accountId),
            )
            ..orderBy([(d) => OrderingTerm.asc(d.name)]))
          .get();
  final out = <DebtEntry>[];
  for (final d in debts) {
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(amount),0) AS s FROM debt_payments WHERE debt_id = ? AND deleted_at IS NULL',
          variables: [Variable.withInt(d.id)],
          readsFrom: {db.debtPayments},
        )
        .getSingle();
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
  final acct = ref.watch(selectedAccountProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.debts, db.debtPayments, db.transactions},
      )
      .watch()
      .asyncMap((_) => fetchDebts(db, accountId: acct));
});

/// Total sisa AKTIF: (utang belum dibayar) vs (piutang belum diterima).
/// Dipakai kartu ringkas Beranda. (sisaUtang, sisaPiutang).
final debtSummaryProvider = StreamProvider<(int, int)>((ref) {
  final db = ref.watch(dbProvider);
  final acct = ref.watch(selectedAccountProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.debts, db.debtPayments, db.transactions},
      )
      .watch()
      .asyncMap((_) async {
        final list = await fetchDebts(db, accountId: acct);
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

/// Cicilan satu utang, terbaru dulu (sembunyikan yang terhapus-lembut).
Stream<List<DebtPayment>> watchDebtPayments(AppDatabase db, int debtId) {
  return (db.select(db.debtPayments)
        ..where((p) => p.debtId.equals(debtId) & p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.desc(p.date)]))
      .watch();
}
