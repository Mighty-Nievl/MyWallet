import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'providers.dart';

// ---------- Transaksi ----------

Future<void> addTransaction(
  WidgetRef ref, {
  required int amount,
  required bool isExpense,
  required int? categoryId,
  required DateTime date,
  required String note,
}) async {
  final db = ref.read(dbProvider);
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: drift.Value(isExpense),
          categoryId: drift.Value(categoryId),
          date: date,
          note: drift.Value(note.trim()),
        ),
      );
}

Future<void> updateTransaction(
  WidgetRef ref, {
  required int id,
  required int amount,
  required bool isExpense,
  required int? categoryId,
  required DateTime date,
  required String note,
}) async {
  final db = ref.read(dbProvider);
  await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
    TransactionsCompanion(
      amount: drift.Value(amount),
      isExpense: drift.Value(isExpense),
      categoryId: drift.Value(categoryId),
      date: drift.Value(date),
      note: drift.Value(note.trim()),
    ),
  );
}

Future<void> deleteTransaction(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
}

// ---------- Kategori ----------

Future<int> addCategory(
  WidgetRef ref, {
  required String name,
  required String icon,
  required bool isExpense,
}) async {
  final db = ref.read(dbProvider);
  return db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: name.trim(),
          icon: drift.Value(icon.trim().isEmpty ? '📦' : icon.trim()),
          isExpense: drift.Value(isExpense),
        ),
      );
}

Future<void> deleteCategory(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
}

// ---------- Budget ----------

Future<void> upsertBudget(
  WidgetRef ref, {
  required int categoryId,
  required int limit,
  required String month,
}) async {
  final db = ref.read(dbProvider);
  final existing = await (db.select(db.budgets)
        ..where((b) =>
            b.categoryId.equals(categoryId) & b.month.equals(month)))
      .getSingleOrNull();
  if (existing == null) {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: categoryId,
            limit: limit,
            month: month,
          ),
        );
  } else {
    await (db.update(db.budgets)..where((b) => b.id.equals(existing.id)))
        .write(BudgetsCompanion(limit: drift.Value(limit)));
  }
}

Future<void> deleteBudget(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  await (db.delete(db.budgets)..where((b) => b.id.equals(id))).go();
}

// ---------- Pengaturan (SharedPreferences) ----------

final prefsProvider =
    FutureProvider<SharedPreferences>((_) => SharedPreferences.getInstance());
