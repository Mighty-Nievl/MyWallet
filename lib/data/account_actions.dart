import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';
import 'sync_meta.dart';

/// Aksi dompet + transfer antar-dompet (v1.25, skema v4) — opsi C.
///
/// Semantik transfer NETRAL (cermin pola "opsi B" [debt_actions]):
/// - 2 kaki cermin bertaut [transferId] grup uuid SAMA:
///   kaki KELUAR dari dompet asal + kaki MASUK ke dompet tujuan.
/// - Kaki transfer DIKECUALIKAN dari agregat pemasukan/pengeluaran
///   ([AppDatabase.getTotals]/totalsByCategory filter
///   `transfer_id IS NULL`) — pindah dompet bukan income/expense.
/// - Kaki transfer MASUK [AppDatabase.getBalance] per dompet
///   (pergerakan dompet yang sah).
/// - Kategori kedua kaki = null; label satu sumber ([transferNote]).
///
/// Overdraft DIIZINKAN di logika (keputusan plan): pencegahan via
/// warning UI di dialog transfer (Fase 3), bukan blokir — utang
/// menutup kasus minus beneran.
///
/// Pola testable ala [fetchBudgets]: fungsi inti menerima [AppDatabase]
/// langsung; wrapper `WidgetRef` tipis untuk UI.

// ---------- Label (satu sumber, dipakai aksi + test + UI) ----------

String transferNote(String note) {
  final n = note.trim();
  return n.isEmpty ? 'Transfer' : 'Transfer · $n';
}

// ---------- Inti (AppDatabase — testable langsung) ----------

/// Kaki transfer satu grup (keluar asal + masuk tujuan), tertua dulu.
Future<List<Transaction>> transferLegs(AppDatabase db, String groupId) {
  return (db.select(db.transactions)
        ..where((t) => t.transferId.equals(groupId))
        ..orderBy([(t) => drift.OrderingTerm.asc(t.id)]))
      .get();
}

/// Pindah dana antar dompet: 2 kaki cermin netral.
/// Validasi: dompet beda + ada, amount > 0.
/// Return grup id (uuid) — dipakai hapus berpasangan.
Future<String> insertTransfer(
  AppDatabase db, {
  required int fromAccountId,
  required int toAccountId,
  required int amount,
  required DateTime date,
  required String note,
}) async {
  if (fromAccountId == toAccountId) {
    throw ArgumentError('Dompet asal dan tujuan harus beda.');
  }
  if (amount <= 0) throw ArgumentError('Nominal harus lebih dari 0.');
  final from = await (db.select(db.accounts)
        ..where((a) => a.id.equals(fromAccountId)))
      .getSingleOrNull();
  final to = await (db.select(db.accounts)
        ..where((a) => a.id.equals(toAccountId)))
      .getSingleOrNull();
  if (from == null || to == null) {
    throw ArgumentError('Dompet tidak ditemukan.');
  }
  final cleanNote = note.trim();
  final groupId = newSyncUuid();
  // Kaki KELUAR (asal): pengeluaran.
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: const drift.Value(true),
          categoryId: const drift.Value(null),
          accountId: drift.Value(fromAccountId),
          accountUuid: drift.Value(from.uuid),
          transferId: drift.Value(groupId),
          date: date,
          note: drift.Value(transferNote(cleanNote)),
        ),
      );
  // Kaki MASUK (tujuan): pemasukan.
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: const drift.Value(false),
          categoryId: const drift.Value(null),
          accountId: drift.Value(toAccountId),
          accountUuid: drift.Value(to.uuid),
          transferId: drift.Value(groupId),
          date: date,
          note: drift.Value(transferNote(cleanNote)),
        ),
      );
  return groupId;
}

/// Hapus transfer berpasangan (kedua kaki sekaligus).
/// Tanpa undo (konfirmasi di UI, ala hapus transaksi).
Future<void> deleteTransfer(AppDatabase db, String groupId) async {
  await (db.delete(db.transactions)
        ..where((t) => t.transferId.equals(groupId)))
      .go();
}

// ---------- Aturan hapus/arsip dompet (Fase 3 UI) ----------

/// Dompet boleh dihapus FISIK hanya bila: saldo 0 (opening + SUM)
/// DAN tanpa transaksi DAN tanpa utang/cicilan.
/// Selain itu tawarkan ARSIP (bukan hapus — riwayat tak jadi yatim).
Future<bool> accountDeletable(AppDatabase db, int accountId) async {
  final acc = await (db.select(db.accounts)
        ..where((a) => a.id.equals(accountId)))
      .getSingleOrNull();
  if (acc == null) return false;
  if (acc.openingBalance != 0) return false;
  if ((await db.getBalance(accountId: accountId)) != 0) return false;
  final txCount =
      await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(accountId)))
          .get();
  if (txCount.isNotEmpty) return false;
  final debtCount =
      await (db.select(db.debts)
            ..where((d) => d.accountId.equals(accountId)))
          .get();
  if (debtCount.isNotEmpty) return false;
  final payCount =
      await (db.select(db.debtPayments)
            ..where((p) => p.accountId.equals(accountId)))
          .get();
  if (payCount.isNotEmpty) return false;
  return true;
}

/// Arsipkan (sembunyikan dari pemilih; riwayat tetap di gabungan).
Future<void> archiveAccount(AppDatabase db, int accountId) async {
  await (db.update(db.accounts)..where((a) => a.id.equals(accountId))).write(
    AccountsCompanion(
      isArchived: const drift.Value(true),
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

/// Hapus fisik — HANYA bila [accountDeletable] true.
Future<void> deleteAccount(AppDatabase db, int accountId) async {
  if (!await accountDeletable(db, accountId)) {
    throw ArgumentError('Dompet berisi — arsipkan, jangan hapus.');
  }
  await (db.delete(db.accounts)..where((a) => a.id.equals(accountId))).go();
}

// ---------- Urutan dompet (v1.29, carousel) ----------

/// Tulis ulang [sortOrder] sesuai urutan [orderedIds] (index 0 = pertama).
/// Id tak dikenal diabaikan; [updatedAt] ikut naik agar urutan ikut sync.
/// Dipakai drag-reorder layar Kelola.
Future<void> reorderAccounts(AppDatabase db, List<int> orderedIds) async {
  for (var i = 0; i < orderedIds.length; i++) {
    final id = orderedIds[i];
    final exists = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (exists == null) continue;
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        sortOrder: drift.Value(i),
        updatedAt: drift.Value(syncNow()),
      ),
    );
  }
}

// ---------- Wrapper WidgetRef (untuk UI) ----------

Future<String> moveTransfer(
  WidgetRef ref, {
  required int fromAccountId,
  required int toAccountId,
  required int amount,
  required DateTime date,
  required String note,
}) => insertTransfer(
  ref.read(dbProvider),
  fromAccountId: fromAccountId,
  toAccountId: toAccountId,
  amount: amount,
  date: date,
  note: note,
);

Future<void> removeTransfer(WidgetRef ref, String groupId) =>
    deleteTransfer(ref.read(dbProvider), groupId);
