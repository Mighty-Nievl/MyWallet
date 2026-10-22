import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';
import 'sync_meta.dart';

// ---------- Transaksi ----------

/// Cari uuid kategori (pendamping categoryId untuk sync Fase 2).
Future<String?> _categoryUuidOf(AppDatabase db, int? categoryId) async {
  if (categoryId == null) return null;
  final cat = await (db.select(
    db.categories,
  )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
  return cat?.uuid;
}

Future<void> addTransaction(
  WidgetRef ref, {
  required int amount,
  required bool isExpense,
  required int? categoryId,
  required DateTime date,
  required String note,
  // v1.25: dompet pemilik. WAJIB diisi pemanggil (form baca dompet
  // aktif, lihat tx_form_screen) — insert NULL dilarang agar baris
  // tak hilang dari filter dompet.
  required int accountId,
}) async {
  final db = ref.read(dbProvider);
  final acc = await (db.select(
    db.accounts,
  )..where((a) => a.id.equals(accountId))).getSingleOrNull();
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: drift.Value(isExpense),
          categoryId: drift.Value(categoryId),
          categoryUuid: drift.Value(await _categoryUuidOf(db, categoryId)),
          accountId: drift.Value(accountId),
          accountUuid: drift.Value(acc?.uuid),
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
      categoryUuid: drift.Value(await _categoryUuidOf(db, categoryId)),
      date: drift.Value(date),
      note: drift.Value(note.trim()),
      // Jejak tulis sync (Fase 0): tiap ubah = updatedAt baru.
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

Future<void> deleteTransaction(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  // Soft-delete (Fase 2): merambat via sync sebagai tombstone, bukan
  // hilang fisik. Query saldo/laporan/riwayat sudah filter deletedAt.
  await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
    TransactionsCompanion(
      deletedAt: drift.Value(syncNow()),
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

/// Kebalikan [deleteTransaction] — tombol "Urungkan" (v1.38.4).
///
/// Sengaja menerima [AppDatabase], bukan `WidgetRef`: dipanggil dari
/// SnackBar setelah form di-pop, jadi widget pemanggilnya sudah dibuang dan
/// `ref`-nya tidak boleh dipakai lagi. `updatedAt` ikut diperbarui supaya
/// kebangkitan baris ini menang LWW saat sync.
Future<void> restoreTransaction(AppDatabase db, int id) async {
  await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
    TransactionsCompanion(
      deletedAt: const drift.Value(null),
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

// ---------- Kategori ----------

Future<int> addCategory(
  WidgetRef ref, {
  required String name,
  required String icon,
  required bool isExpense,
}) async {
  final db = ref.read(dbProvider);
  return db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          name: name.trim(),
          icon: drift.Value(icon.trim().isEmpty ? '📦' : icon.trim()),
          isExpense: drift.Value(isExpense),
        ),
      );
}

Future<void> deleteCategory(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  // Soft-delete (Fase 2): tombstone merambat, transaksi lama jadi
  // "Tanpa kategori" tapi tidak hilang.
  await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      deletedAt: drift.Value(syncNow()),
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

// ---------- Budget ----------

Future<void> upsertBudget(
  WidgetRef ref, {
  required int categoryId,
  required int limit,
  required String month,
}) async {
  final db = ref.read(dbProvider);
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
      BudgetsCompanion(
        limit: drift.Value(limit),
        // v1.36.2: Undo setelah hapus = hidupkan lagi tombstones.
        // Dulu deletedAt dibiarkan, jadi baris "kembali" tapi tetap
        // tersembunyi dari daftar.
        deletedAt: const drift.Value(null),
        // Jejak tulis sync (Fase 0).
        updatedAt: drift.Value(syncNow()),
      ),
    );
  }
}

Future<void> deleteBudget(WidgetRef ref, int id) async {
  final db = ref.read(dbProvider);
  // Soft-delete (Fase 2): tombstone merambat.
  await (db.update(db.budgets)..where((b) => b.id.equals(id))).write(
    BudgetsCompanion(
      deletedAt: drift.Value(syncNow()),
      updatedAt: drift.Value(syncNow()),
    ),
  );
}
