import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';
import 'sync_meta.dart';

/// Logika manajer utang-piutang (v1.15, skema v2) — opsi B.
///
/// Semantik saldo OTOMATIS (transaksi CERMIN di `transactions`):
/// - UTANG (isDebt=true, aku pinjam): catat = PEMASUKAN (+total),
///   tiap bayar = PENGELUARAN.
/// - PIUTANG (isDebt=false, aku meminjami): catat = PENGELUARAN (−total),
///   tiap terima = PEMASUKAN.
///
/// Karena cermin = baris transaksi biasa (flag debtId/debtPaymentId),
/// saldo + laporan + riwayat + PDF + CSV ikut OTOMATIS tanpa ubah
/// satu pun query lama. Status lunas TIDAK disimpan — dihitung
/// (paid >= total) agar tidak basi.
///
/// Pola testable ala [fetchBudgets]: fungsi inti menerima [AppDatabase]
/// langsung (dipakai test in-memory); wrapper `WidgetRef` tipis untuk UI.

/// Dilempar bila cicilan melebihi sisa ([remaining]).
class DebtOverpayException implements Exception {
  const DebtOverpayException(this.remaining);
  final int remaining;
  @override
  String toString() =>
      'Melebihi sisa. Maksimal ${remaining <= 0 ? 0 : remaining}.';
}

/// Dilempar bila total baru < yang sudah dibayar.
class DebtInvalidTotalException implements Exception {
  const DebtInvalidTotalException(this.paid);
  final int paid;
}

// ---------- Label cermin (satu sumber, dipakai aksi + test) ----------

String debtPrincipalNote(bool isDebt, String name) =>
    '${isDebt ? 'Utang' : 'Piutang'} — $name';

String debtPaymentNote(bool isDebt, String name) =>
    '${isDebt ? 'Bayar utang' : 'Terima piutang'} — $name';

String _mirrorNote(String label, String note) {
  final n = note.trim();
  return n.isEmpty ? label : '$label · $n';
}

// ---------- Inti (AppDatabase — testable langsung) ----------

/// Total sudah dibayar untuk satu utang (SUM cicilan, tanpa yang
/// terhapus-lembut).
Future<int> debtPaidOf(AppDatabase db, int debtId) async {
  final row = await db
      .customSelect(
        'SELECT COALESCE(SUM(amount),0) AS s FROM debt_payments WHERE debt_id = ? AND deleted_at IS NULL',
        variables: [drift.Variable.withInt(debtId)],
        readsFrom: {db.debtPayments},
      )
      .getSingle();
  return row.read<int>('s');
}

/// Catat utang/piutang baru + transaksi cermin pokok.
/// Return id utang. Validasi: nama tidak kosong, total > 0.
///
/// v1.25: [accountId] WAJIB (dompet aktif saat catat). Cermin pokok
/// ikut dompet yang sama.
Future<int> insertDebt(
  AppDatabase db, {
  required String name,
  required bool isDebt,
  required int total,
  required DateTime date,
  required DateTime? dueDate,
  required String note,
  required int accountId,
}) async {
  final n = name.trim();
  if (n.isEmpty) throw ArgumentError('Nama tidak boleh kosong.');
  if (total <= 0) throw ArgumentError('Total harus lebih dari 0.');
  final cleanNote = note.trim();
  final acc = await (db.select(
    db.accounts,
  )..where((a) => a.id.equals(accountId))).getSingleOrNull();

  final id = await db
      .into(db.debts)
      .insert(
        DebtsCompanion.insert(
          name: n,
          isDebt: drift.Value(isDebt),
          total: total,
          date: date,
          dueDate: drift.Value(dueDate),
          note: drift.Value(cleanNote),
          accountId: drift.Value(accountId),
        ),
      );
  // Cermin pokok: utang = uang MASUK, piutang = uang KELUAR.
  // uuid/updatedAt terisi otomatis via clientDefault (sync_meta).
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: total,
          isExpense: drift.Value(!isDebt),
          categoryId: const drift.Value(null),
          accountId: drift.Value(accountId),
          accountUuid: drift.Value(acc?.uuid),
          date: date,
          note: drift.Value(
            _mirrorNote(debtPrincipalNote(isDebt, n), cleanNote),
          ),
          debtId: drift.Value(id),
        ),
      );
  return id;
}

/// Bayar/terima cicilan + transaksi cermin.
/// Validasi: amount > 0, tidak melebihi sisa ([DebtOverpayException]).
/// Return id cicilan.
///
/// v1.25: cicilan IKUT DOMPET INDUK (bukan dompet aktif) — bayar utang
/// dompet X harus keluar dari X walau user sedang melihat Y.
Future<int> insertDebtPayment(
  AppDatabase db, {
  required int debtId,
  required int amount,
  required DateTime date,
  required String note,
}) async {
  if (amount <= 0) throw ArgumentError('Nominal harus lebih dari 0.');
  final debt = await (db.select(
    db.debts,
  )..where((d) => d.id.equals(debtId))).getSingleOrNull();
  if (debt == null) throw ArgumentError('Utang tidak ditemukan.');
  final paid = await debtPaidOf(db, debtId);
  final remain = debt.total - paid;
  if (amount > remain) throw DebtOverpayException(remain);
  final cleanNote = note.trim();
  final parentAcct = debt.accountId == null
      ? null
      : await (db.select(
          db.accounts,
        )..where((a) => a.id.equals(debt.accountId!))).getSingleOrNull();

  final payId = await db
      .into(db.debtPayments)
      .insert(
        DebtPaymentsCompanion.insert(
          debtId: debtId,
          amount: amount,
          date: date,
          note: drift.Value(cleanNote),
          accountId: drift.Value(debt.accountId),
        ),
      );
  // Cermin cicilan: bayar utang = KELUAR, terima piutang = MASUK.
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amount: amount,
          isExpense: drift.Value(debt.isDebt),
          categoryId: const drift.Value(null),
          accountId: drift.Value(debt.accountId),
          accountUuid: drift.Value(parentAcct?.uuid),
          date: date,
          note: drift.Value(
            _mirrorNote(debtPaymentNote(debt.isDebt, debt.name), cleanNote),
          ),
          debtId: drift.Value(debtId),
          debtPaymentId: drift.Value(payId),
        ),
      );
  return payId;
}

/// Ubah utang: nama/total/tanggal/jatuh tempo/catatan.
/// Cermin pokok ikut disinkron (nominal + tanggal + label nama).
/// Total baru < yang sudah dibayar → [DebtInvalidTotalException].
Future<void> updateDebt(
  AppDatabase db, {
  required int id,
  required String name,
  required int total,
  required DateTime date,
  required DateTime? dueDate,
  required String note,
}) async {
  final n = name.trim();
  if (n.isEmpty) throw ArgumentError('Nama tidak boleh kosong.');
  if (total <= 0) throw ArgumentError('Total harus lebih dari 0.');
  final debt = await (db.select(
    db.debts,
  )..where((d) => d.id.equals(id))).getSingleOrNull();
  if (debt == null) throw ArgumentError('Utang tidak ditemukan.');
  final paid = await debtPaidOf(db, id);
  if (total < paid) throw DebtInvalidTotalException(paid);
  final cleanNote = note.trim();

  await (db.update(db.debts)..where((d) => d.id.equals(id))).write(
    DebtsCompanion(
      name: drift.Value(n),
      total: drift.Value(total),
      date: drift.Value(date),
      dueDate: drift.Value(dueDate),
      note: drift.Value(cleanNote),
      // Jejak tulis sync (Fase 0).
      updatedAt: drift.Value(syncNow()),
    ),
  );
  // Sinkron cermin pokok (baris debtPaymentId IS NULL milik utang ini).
  await (db.update(
    db.transactions,
  )..where((t) => t.debtId.equals(id) & t.debtPaymentId.isNull())).write(
    TransactionsCompanion(
      amount: drift.Value(total),
      date: drift.Value(date),
      note: drift.Value(
        _mirrorNote(debtPrincipalNote(debt.isDebt, n), cleanNote),
      ),
      // Jejak tulis sync (Fase 0).
      updatedAt: drift.Value(syncNow()),
    ),
  );
}

/// Hapus utang + SEMUA cicilan + SEMUA cermin (pokok & cicilan).
/// Tanpa undo (ada dialog konfirmasi di UI, ala hapus transaksi).
/// Hapus EKSPLISIT berurutan (cermin → cicilan → utang): tidak ngandelin
/// FK cascade karena SQLite bisa jalan dengan foreign_keys pragma OFF.
Future<void> deleteDebt(AppDatabase db, int id) async {
  await (db.delete(db.transactions)..where((t) => t.debtId.equals(id))).go();
  await (db.delete(db.debtPayments)..where((p) => p.debtId.equals(id))).go();
  await (db.delete(db.debts)..where((d) => d.id.equals(id))).go();
}

/// Hapus satu cicilan + cerminnya. Tanpa undo (konfirmasi di UI).
Future<void> deleteDebtPayment(AppDatabase db, int paymentId) async {
  await (db.delete(
    db.transactions,
  )..where((t) => t.debtPaymentId.equals(paymentId))).go();
  await (db.delete(db.debtPayments)..where((p) => p.id.equals(paymentId))).go();
}

// ---------- Wrapper WidgetRef (untuk UI) ----------

Future<int> addDebt(
  WidgetRef ref, {
  required String name,
  required bool isDebt,
  required int total,
  required DateTime date,
  required DateTime? dueDate,
  required String note,
}) async {
  final db = ref.read(dbProvider);
  // v1.25: utang baru milik dompet aktif (bila "Semua" = dompet pertama).
  final acct = await defaultAccountId(
    db,
    ref.read(selectedAccountProvider),
  );
  if (acct == null) throw ArgumentError('Belum ada dompet.');
  return insertDebt(
    db,
    name: name,
    isDebt: isDebt,
    total: total,
    date: date,
    dueDate: dueDate,
    note: note,
    accountId: acct,
  );
}

Future<int> addDebtPayment(
  WidgetRef ref, {
  required int debtId,
  required int amount,
  required DateTime date,
  required String note,
}) => insertDebtPayment(
  ref.read(dbProvider),
  debtId: debtId,
  amount: amount,
  date: date,
  note: note,
);

Future<void> editDebt(
  WidgetRef ref, {
  required int id,
  required String name,
  required int total,
  required DateTime date,
  required DateTime? dueDate,
  required String note,
}) => updateDebt(
  ref.read(dbProvider),
  id: id,
  name: name,
  total: total,
  date: date,
  dueDate: dueDate,
  note: note,
);

Future<void> removeDebt(WidgetRef ref, int id) =>
    deleteDebt(ref.read(dbProvider), id);

Future<void> removeDebtPayment(WidgetRef ref, int paymentId) =>
    deleteDebtPayment(ref.read(dbProvider), paymentId);
