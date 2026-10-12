// Test migrasi v3→v4 dompet ganda (Fase 1, plan v1.25.0).
//
// Simulasi baris gaya-lama: insert TANPA accountId (nullable) lalu
// backfillAccounts() — assert semua jatuh ke "Utama" + accountUuid
// terisi + saldo tak berubah sepeser pun.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
  });

  tearDown(() async {
    await db.close();
  });

  test('migrasi v4: baris lama → Utama, saldo utuh', () async {
    // Simulasi gaya-lama: insertDebt() v1.25 WAJIB accountId, jadi
    // baris pra-migrasi dibuat via companion langsung (nullable) lalu
    // dipaksa NULL via SQL — persis kondisi kolom baru pasca-ADD COLUMN.
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: 250000,
            isExpense: const Value(true),
            categoryId: const Value(1),
            date: DateTime(2026, 10, 5, 12),
            note: const Value('gaya lama'),
          ),
        );
    await db
        .into(db.debts)
        .insert(
          DebtsCompanion.insert(
            name: 'Budi',
            total: 100000,
            date: DateTime(2026, 10, 1),
            note: const Value(''),
          ),
        );
    await db.customStatement(
      "UPDATE transactions SET account_id = NULL WHERE note = 'gaya lama'",
    );
    await db.customStatement(
      "UPDATE debts SET account_id = NULL WHERE name = 'Budi'",
    );
    final saldoSebelum = await db.getBalance();

    await db.backfillAccounts();

    final accs = await db.select(db.accounts).get();
    expect(accs.map((a) => a.name), contains('Utama'));
    final utama = accs.firstWhere((a) => a.name == 'Utama');

    final txs = await db.select(db.transactions).get();
    expect(txs, isNotEmpty);
    expect(txs.every((t) => t.accountId == utama.id), isTrue);
    expect(txs.every((t) => t.accountUuid == utama.uuid), isTrue);

    final debts = await db.select(db.debts).get();
    expect(debts.every((d) => d.accountId == utama.id), isTrue);

    // Idempoten: panggil 2x → tetap 1 Utama, saldo sama.
    await db.backfillAccounts();
    final accs2 = await db.select(db.accounts).get();
    expect(accs2.where((a) => a.name == 'Utama'), hasLength(1));
    expect(await db.getBalance(), saldoSebelum);
  });

  test('getBalance per dompet: filter accountId', () async {
    await db.backfillAccounts();
    final utama = (await db.select(db.accounts).get()).firstWhere(
      (a) => a.name == 'Utama',
    );
    final keluargaId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Keluarga'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: 500000,
            isExpense: const Value(false),
            categoryId: const Value(9),
            date: DateTime(2026, 10, 6, 8),
            note: const Value('gaji keluarga'),
            accountId: Value(keluargaId),
          ),
        );
    // Gabungan (tanpa filter) = semua.
    expect(await db.getBalance(), 500000);
    // Per dompet.
    expect(await db.getBalance(accountId: keluargaId), 500000);
    expect(await db.getBalance(accountId: utama.id), 0);
  });
}
