// v1.38.4 — hapus transaksi bisa diurungkan.
//
// Hapus transaksi = soft-delete (`deletedAt` tombstone), jadi "Urungkan" di
// SnackBar cukup membersihkan tombstone-nya. Yang diuji di sini adalah
// kontrak `restoreTransaction`: baris yang sempat hilang dari hitungan
// kembali terhitung, dan tombstone-nya benar-benar kosong (bukan 0/epoch).
//
// Catatan: `deleteTransaction` sendiri tidak dipanggil di sini karena
// signature-nya butuh `WidgetRef`; SQL-nya 3 baris dan sudah ada sejak
// Fase 2, jadi test ini menirunya lewat write langsung.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/actions.dart';
import 'package:mywallet/data/database.dart';

void main() {
  test('restoreTransaction mengembalikan transaksi yang dihapus', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.backfillAccounts();

    final utama = (await db.select(db.accounts).get())
        .firstWhere((a) => a.name == 'Utama')
        .id;
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: 45000,
            isExpense: const Value(true),
            categoryId: const Value(1),
            date: DateTime.now(),
            accountId: Value(utama),
          ),
        );

    expect(await db.watchTxCount().first, 1, reason: 'transaksi awal ada');

    // Tiru deleteTransaction: tombstone + updatedAt.
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    expect(
      await db.watchTxCount().first,
      0,
      reason: 'tombstone menyembunyikan baris dari hitungan',
    );

    await restoreTransaction(db, id);

    expect(
      await db.watchTxCount().first,
      1,
      reason: 'Urungkan harus mengembalikan baris ke hitungan',
    );
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.deletedAt, isNull, reason: 'tombstone harus kosong, bukan 0');
  });
}
