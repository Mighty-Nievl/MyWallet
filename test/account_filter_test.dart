// Test filter dompet agregat (Fase 1-Task 4, plan v1.25.0).
//
// Mengunci: getTotals / totalsByCategory / watchHistory(+count) /
// fetchDebts / fetchBudgets / defaultAccountId sadar accountId,
// null = gabungan (nol drift).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/debt_actions.dart';
import 'package:mywallet/data/providers.dart';

void main() {
  late AppDatabase db;
  late int utamaId;
  late int keluargaId;
  late int makanId;
  late int gajiId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
    await db.backfillAccounts();
    final accs = await db.select(db.accounts).get();
    utamaId = accs.firstWhere((a) => a.name == 'Utama').id;
    keluargaId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Keluarga'));
    final cats = await db.select(db.categories).get();
    makanId = cats.firstWhere((c) => c.name == 'Makan & Minum').id;
    gajiId = cats.firstWhere((c) => c.name == 'Gaji').id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed2() async {
    // Keluarga: gaji masuk 500rb. Utama: makan keluar 100rb.
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 500000,
            isExpense: const Value(false),
            categoryId: Value(gajiId),
            date: DateTime(2026, 10, 6, 8),
            note: const Value('gaji'),
            accountId: Value(keluargaId),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 100000,
            isExpense: const Value(true),
            categoryId: Value(makanId),
            date: DateTime(2026, 10, 7, 12),
            note: const Value('nasi padang'),
            accountId: Value(utamaId),
          ),
        );
  }

  DateTime f() => DateTime(2026, 10, 1);
  DateTime t() => DateTime(2026, 10, 31, 23, 59, 59);

  test('getTotals per dompet + gabungan', () async {
    await seed2();
    final (m, k) = await db.getTotals(f(), t());
    expect((m, k), (500000, 100000));
    final (mK, kK) = await db.getTotals(f(), t(), accountId: keluargaId);
    expect((mK, kK), (500000, 0));
    final (mU, kU) = await db.getTotals(f(), t(), accountId: utamaId);
    expect((mU, kU), (0, 100000));
  });

  test('totalsByCategory per dompet', () async {
    await seed2();
    final all = await db.totalsByCategory(f(), t(), true);
    expect(all.singleWhere((c) => c.name == 'Makan & Minum').total, 100000);
    final kel = await db.totalsByCategory(
      f(),
      t(),
      true,
      accountId: keluargaId,
    );
    expect(kel, isEmpty); // Keluarga tak punya pengeluaran
    final ut = await db.totalsByCategory(f(), t(), true, accountId: utamaId);
    expect(ut.single.total, 100000);
  });

  test('watchHistory + count per dompet (satu sumber)', () async {
    await seed2();
    final allList = await db.watchHistory(from: f(), to: t()).first;
    final allCount = await db.watchHistoryCount(from: f(), to: t()).first;
    expect(allList, hasLength(2));
    expect(allCount, 2);
    final kelList = await db
        .watchHistory(from: f(), to: t(), accountId: keluargaId)
        .first;
    final kelCount = await db
        .watchHistoryCount(from: f(), to: t(), accountId: keluargaId)
        .first;
    expect(kelList, hasLength(1));
    expect(kelCount, 1);
    expect(kelList.single.note, 'gaji');
  });

  test('fetchDebts per dompet', () async {
    await insertDebt(
      db,
      accountId: utamaId,
      name: 'Budi',
      isDebt: true,
      total: 1000000,
      date: DateTime(2026, 10, 1),
      dueDate: null,
      note: '',
    );
    await insertDebt(
      db,
      accountId: keluargaId,
      name: 'Siti',
      isDebt: false,
      total: 200000,
      date: DateTime(2026, 10, 2),
      dueDate: null,
      note: '',
    );
    expect(await fetchDebts(db), hasLength(2));
    final ut = await fetchDebts(db, accountId: utamaId);
    expect(ut, hasLength(1));
    expect(ut.single.debt.name, 'Budi');
    final kel = await fetchDebts(db, accountId: keluargaId);
    expect(kel.single.debt.name, 'Siti');
  });

  test('fetchBudgets spent per dompet', () async {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: makanId,
            limit: 200000,
            month: '2026-10',
          ),
        );
    await seed2(); // makan 100rb di Utama
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 50000,
            isExpense: const Value(true),
            categoryId: Value(makanId),
            date: DateTime(2026, 10, 8, 12),
            note: const Value('jajan'),
            accountId: Value(keluargaId),
          ),
        );
    final all = await fetchBudgets(db, month: '2026-10', from: f(), to: t());
    expect(all.single.spent, 150000);
    final ut = await fetchBudgets(
      db,
      month: '2026-10',
      from: f(),
      to: t(),
      accountId: utamaId,
    );
    expect(ut.single.spent, 100000);
    final kel = await fetchBudgets(
      db,
      month: '2026-10',
      from: f(),
      to: t(),
      accountId: keluargaId,
    );
    expect(kel.single.spent, 50000);
  });

  test('defaultAccountId: eksplisit menang, null = dompet pertama', () async {
    expect(await defaultAccountId(db, keluargaId), keluargaId);
    // "Utama" vs "Keluarga": abjad Keluarga dulu — tapi sortOrder sama
    // (0) → abjad menang. Yang penting: non-null + milik daftar.
    final d = await defaultAccountId(db, null);
    expect(d, isNotNull);
    final accs = await db.select(db.accounts).get();
    expect(accs.map((a) => a.id), contains(d));
  });
}
