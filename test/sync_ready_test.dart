import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/debt_actions.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/sync_meta.dart';

/// Test sync-ready Fase 0 (v1.16, skema v3) — TANPA network.
///
/// Strategi ala debt_test/budget_test: db in-memory langsung.
/// - [newSyncUuid]: format UUID v4 + unik.
/// - DB fresh (onCreate v3): seed kategori langsung punya uuid/updatedAt.
/// - [AppDatabase.backfillSyncMeta]: baris gaya-lama (uuid null,
///   updatedAt null, tanpa categoryUuid) → terisi semua dengan benar.
/// - Insert baru tanpa sebut uuid/updatedAt → terisi otomatis
///   via clientDefault (bukti kolom sync jalan tanpa ubah actions/test).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
  });

  tearDown(() async {
    await db.close();
  });

  group('newSyncUuid', () {
    test('format UUID v4', () {
      for (var i = 0; i < 20; i++) {
        expect(syncUuidPattern.hasMatch(newSyncUuid()), isTrue,
            reason: 'bukan UUID v4: ${newSyncUuid()}');
      }
    });

    test('1000x tanpa tabrakan', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        final u = newSyncUuid();
        expect(seen, isNot(contains(u)), reason: 'tabrakan: $u');
        seen.add(u);
      }
    });
  });

  group('seed fresh (onCreate v3)', () {
    test('kategori bawaan langsung punya uuid unik + updatedAt', () async {
      final cats = await db.select(db.categories).get();
      expect(cats, isNotEmpty);
      for (final c in cats) {
        expect(c.uuid, isNotNull);
        expect(syncUuidPattern.hasMatch(c.uuid!), isTrue);
        expect(c.updatedAt, isNotNull);
        expect(c.deletedAt, isNull);
        expect(c.householdId, isNull); // pribadi = null
      }
      final uuids = cats.map((c) => c.uuid!).toSet();
      expect(uuids, hasLength(cats.length)); // unik semua
    });

    test('insert baru tanpa uuid → terisi otomatis', () async {
      final cat = (await db.select(db.categories).get()).first;
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: 50000,
              isExpense: const Value(true),
              categoryId: Value(cat.id),
              date: DateTime(2026, 10, 10),
            ),
          );
      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.uuid, isNotNull);
      expect(syncUuidPattern.hasMatch(tx.uuid!), isTrue);
      expect(tx.updatedAt, isNotNull);
      expect(tx.deletedAt, isNull);
      // categoryUuid TIDAK otomatis dari FK (ditulis actions) — boleh null.
      expect(tx.categoryUuid, isNull);
    });
  });

  group('backfillSyncMeta (baris gaya-lama)', () {
    /// Sisipkan baris seolah dari skema v2: uuid/updatedAt NULL eksplisit.
    Future<void> insertLegacy() async {
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Legacy Cat',
              uuid: const Value(null),
              updatedAt: const Value(null),
            ),
          );
      // createdAt eksplisit agar bisa dicek updatedAt ikut.
      final created = DateTime(2025, 5, 5, 10, 30);
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: 75000,
              isExpense: const Value(false),
              categoryId: Value(catId),
              date: DateTime(2025, 5, 6),
              createdAt: Value(created),
              uuid: const Value(null),
              updatedAt: const Value(null),
            ),
          );
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: catId,
              limit: 100000,
              month: '2025-05',
              uuid: const Value(null),
              updatedAt: const Value(null),
            ),
          );
      final debtId = await db.into(db.debts).insert(
            DebtsCompanion.insert(
              name: 'Legacy Debt',
              total: 200000,
              date: DateTime(2025, 5, 1),
              createdAt: Value(created),
              uuid: const Value(null),
              updatedAt: const Value(null),
            ),
          );
      await db.into(db.debtPayments).insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              amount: 50000,
              date: DateTime(2025, 5, 2),
              createdAt: Value(created),
              uuid: const Value(null),
              updatedAt: const Value(null),
            ),
          );
    }

    test('uuid terisi unik + updatedAt = createdAt + categoryUuid', () async {
      await insertLegacy();
      await db.backfillSyncMeta();

      // 1) uuid: semua terisi + unik global antar-tabel.
      final allUuids = <String>{};
      var count = 0;
      for (final rows in [
        await db.select(db.categories).get(),
        await db.select(db.transactions).get(),
        await db.select(db.budgets).get(),
        await db.select(db.debts).get(),
        await db.select(db.debtPayments).get(),
      ]) {
        for (final r in rows) {
          final u = (r as dynamic).uuid;
          expect(u, isNotNull, reason: 'uuid null di $r');
          final s = u as String;
          expect(syncUuidPattern.hasMatch(s), isTrue);
          expect(allUuids, isNot(contains(s)));
          allUuids.add(s);
          count++;
        }
      }
      expect(count, greaterThan(10)); // seed + legacy

      // 2) updatedAt transaksi legacy = createdAt-nya.
      final tx = (await db.select(db.transactions).get())
          .firstWhere((t) => t.amount == 75000);
      expect(tx.updatedAt, isNotNull);
      expect(tx.updatedAt, tx.createdAt);

      // 3) categoryUuid transaksi legacy = uuid kategori induk.
      final cat = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Legacy Cat');
      expect(tx.categoryUuid, cat.uuid);

      // 4) budgets (tanpa createdAt) → updatedAt = jam backfill.
      final before = DateTime.now().subtract(const Duration(minutes: 5));
      final budget = (await db.select(db.budgets).get())
          .firstWhere((b) => b.month == '2025-05');
      expect(budget.updatedAt, isNotNull);
      expect(budget.updatedAt!.isAfter(before), isTrue);
    });

    test('idempoten: jalan 2x tidak merusak', () async {
      await insertLegacy();
      await db.backfillSyncMeta();
      final tx1 = (await db.select(db.transactions).get())
          .firstWhere((t) => t.amount == 75000);
      await db.backfillSyncMeta();
      final tx2 = (await db.select(db.transactions).get())
          .firstWhere((t) => t.amount == 75000);
      expect(tx2.uuid, tx1.uuid);
      expect(tx2.updatedAt, tx1.updatedAt);
      expect(tx2.categoryUuid, tx1.categoryUuid);
    });
  });

  group('soft-delete disembunyikan query (kontrak Fase 2)', () {
    test('saldo + riwayat + pie abaikan baris terhapus-lembut', () async {
      final cat = (await db.select(db.categories).get()).first;
      final d = DateTime(2026, 10, 10);
      final idHidup = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: 100000,
              isExpense: const Value(true),
              categoryId: Value(cat.id),
              date: d,
            ),
          );
      final idHapus = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              amount: 900000,
              isExpense: const Value(true),
              categoryId: Value(cat.id),
              date: d,
            ),
          );
      // Hapus-lembut: isi deletedAt (Fase 2 nanti via aksi, Fase 0 manual).
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(idHapus)))
          .write(TransactionsCompanion(deletedAt: Value(syncNow())));

      expect(await db.getBalance(), -100000);
      final (masuk, keluar) = await db.getTotals(
          DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59));
      expect((masuk, keluar), (0, 100000));
      final history =
          await db.watchHistory(from: DateTime(2026, 10, 1)).first;
      expect(history.map((e) => e.id), contains(idHidup));
      expect(history.map((e) => e.id), isNot(contains(idHapus)));
      final pie = await db.totalsByCategory(
          DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59), true);
      expect(pie.single.total, 100000);
    });

    test('fetchDebts + debtPaidOf abaikan utang/cicilan terhapus', () async {
      final debtId = await db.into(db.debts).insert(
            DebtsCompanion.insert(
              name: 'Hantu',
              total: 500000,
              date: DateTime(2026, 10, 1),
            ),
          );
      final payId = await db.into(db.debtPayments).insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              amount: 500000,
              date: DateTime(2026, 10, 2),
            ),
          );
      expect(await debtPaidOf(db, debtId), 500000);
      // Hapus-lembut cicilannya → paid kembali 0.
      await (db.update(db.debtPayments)
            ..where((p) => p.id.equals(payId)))
          .write(DebtPaymentsCompanion(deletedAt: Value(syncNow())));
      expect(await debtPaidOf(db, debtId), 0);
      // Hapus-lembut utangnya → hilang dari daftar.
      await (db.update(db.debts)..where((x) => x.id.equals(debtId)))
          .write(DebtsCompanion(deletedAt: Value(syncNow())));
      expect(await fetchDebts(db), isEmpty);
    });

    test('fetchBudgets abaikan budget terhapus', () async {
      final cat = (await db.select(db.categories).get())
          .firstWhere((c) => c.isExpense);
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: cat.id,
              limit: 300000,
              month: '2026-10',
            ),
          );
      final (from, to) = monthRangeOf('2026-10');
      expect(
          await fetchBudgets(db, month: '2026-10', from: from, to: to),
          hasLength(1));
      await (db.update(db.budgets)
            ..where((b) =>
                b.categoryId.equals(cat.id) & b.month.equals('2026-10')))
          .write(BudgetsCompanion(deletedAt: Value(syncNow())));
      expect(
          await fetchBudgets(db, month: '2026-10', from: from, to: to),
          isEmpty);
    });
  });
}
