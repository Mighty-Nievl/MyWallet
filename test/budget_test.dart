import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';

/// Test CRUD budget — nutup kritik coverage 0%.
///
/// Strategi: test fungsi murni langsung dengan db in-memory
/// (tanpa ProviderContainer/widget):
/// - insert/update via query Drift langsung (cerminan upsertBudget)
/// - baca via [fetchBudgets] (logika yang dipakai budgetsProvider)
/// - delete via query langsung (cerminan deleteBudget)
///
/// Alasan: actions memakai WidgetRef sehingga butuh widget harness;
/// logika provider yang rawan bug (refresh + urutan) sudah dicabut
/// ke [fetchBudgets] yang testable langsung. Test ini tidak hang.

Future<void> upsertDb(
  AppDatabase db, {
  required int categoryId,
  required int limit,
  required String month,
}) async {
  final existing =
      await (db.select(db.budgets)..where(
            (b) => b.categoryId.equals(categoryId) & b.month.equals(month),
          ))
          .getSingleOrNull();
  if (existing == null) {
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: categoryId,
            limit: limit,
            month: month,
          ),
        );
  } else {
    await (db.update(db.budgets)..where((b) => b.id.equals(existing.id))).write(
      BudgetsCompanion(limit: Value(limit)),
    );
  }
}

void main() {
  late AppDatabase db;
  late int utamaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Picu onCreate + seed kategori bawaan.
    await db.select(db.categories).get();
    await db.backfillAccounts(); // seed Utama (v1.25)
    utamaId = (await db.select(db.accounts).get())
        .firstWhere((a) => a.name == 'Utama')
        .id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<Category> firstExpenseCat() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.isExpense);
  }

  group('upsert (cerminan upsertBudget)', () {
    test('insert baru lalu update limit kategori+bulan yang sama', () async {
      final cat = await firstExpenseCat();

      await upsertDb(db, categoryId: cat.id, limit: 500000, month: '2026-10');
      var rows =
          await (db.select(db.budgets)..where(
                (b) => b.categoryId.equals(cat.id) & b.month.equals('2026-10'),
              ))
              .get();
      expect(rows, hasLength(1));
      expect(rows.single.limit, 500000);

      // Simpan lagi = ubah limit, BUKAN nambah baris.
      await upsertDb(db, categoryId: cat.id, limit: 700000, month: '2026-10');
      rows =
          await (db.select(db.budgets)..where(
                (b) => b.categoryId.equals(cat.id) & b.month.equals('2026-10'),
              ))
              .get();
      expect(rows, hasLength(1));
      expect(rows.single.limit, 700000);
    });

    test('bulan beda = baris beda', () async {
      final cat = await firstExpenseCat();

      await upsertDb(db, categoryId: cat.id, limit: 500000, month: '2026-10');
      await upsertDb(db, categoryId: cat.id, limit: 600000, month: '2026-11');
      final rows = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(cat.id))).get();
      expect(rows, hasLength(2));
    });
  });

  group('delete (cerminan deleteBudget)', () {
    test('hapus menghilangkan baris', () async {
      final cat = await firstExpenseCat();
      await upsertDb(db, categoryId: cat.id, limit: 500000, month: '2026-10');
      final row =
          await (db.select(db.budgets)..where(
                (b) => b.categoryId.equals(cat.id) & b.month.equals('2026-10'),
              ))
              .getSingle();

      await (db.delete(db.budgets)..where((b) => b.id.equals(row.id))).go();
      final rows = await db.select(db.budgets).get();
      expect(rows, isEmpty);
    });
  });

  group('fetchBudgets (logika budgetsProvider)', () {
    test('simpan terlihat + spent 0 + urutan stabil abjad', () async {
      final (from, to) = monthRangeOf('2026-10');

      // Awal: kosong.
      var list = await fetchBudgets(db, month: '2026-10', from: from, to: to);
      expect(list, isEmpty);

      final cats = (await db.select(db.categories).get())
          .where((c) => c.isExpense)
          .toList();
      // Simpan dengan urutan terbalik (Z dulu, A belakangan).
      final reversed = [...cats]..sort((a, b) => b.name.compareTo(a.name));
      for (final c in reversed.take(2)) {
        await upsertDb(db, categoryId: c.id, limit: 500000, month: '2026-10');
      }

      list = await fetchBudgets(db, month: '2026-10', from: from, to: to);
      expect(list, hasLength(2));
      expect(list.every((e) => e.spent == 0), isTrue);
      final names = list.map((e) => e.name).toList();
      expect(names, orderedEquals([...names]..sort()));
    });

    test('filter per bulan', () async {
      final cat = await firstExpenseCat();
      await upsertDb(db, categoryId: cat.id, limit: 500000, month: '2026-10');
      await upsertDb(db, categoryId: cat.id, limit: 600000, month: '2026-11');

      final (from, to) = monthRangeOf('2026-10');
      final list = await fetchBudgets(db, month: '2026-10', from: from, to: to);
      expect(list, hasLength(1));
      expect(list.single.budget.limit, 500000);
    });

    test('spent dihitung dari transaksi bulan itu', () async {
      final cat = await firstExpenseCat();
      await upsertDb(db, categoryId: cat.id, limit: 500000, month: '2026-10');
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 150000,
              isExpense: const Value(true),
              categoryId: Value(cat.id),
              date: DateTime(2026, 10, 15),
              accountId: Value(utamaId),
            ),
          );

      final (from, to) = monthRangeOf('2026-10');
      final list = await fetchBudgets(db, month: '2026-10', from: from, to: to);
      expect(list.single.spent, 150000);
    });
  });
}
