// Test transfer antar-dompet (Fase 2, plan v1.25.0).
//
// Mengunci netralitas: saldo pindah, gabungan tetap, totals tak
// kembung, hapus berpasangan, validasi, aturan hapus/arsip dompet.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';

void main() {
  late AppDatabase db;
  late int utamaId;
  late int keluargaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
    await db.backfillAccounts();
    utamaId = (await db.select(db.accounts).get())
        .firstWhere((a) => a.name == 'Utama')
        .id;
    keluargaId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Keluarga'));
  });

  tearDown(() async {
    await db.close();
  });

  DateTime f() => DateTime(2026, 10, 1);
  DateTime t() => DateTime(2026, 10, 31, 23, 59, 59);

  test('transfer 100rb: saldo pindah, gabungan tetap', () async {
    final g = await insertTransfer(
      db,
      fromAccountId: utamaId,
      toAccountId: keluargaId,
      amount: 100000,
      date: DateTime(2026, 10, 10, 12),
      note: 'uang belanja',
    );
    expect(g, isNotEmpty);
    expect(await db.getBalance(accountId: utamaId), -100000);
    expect(await db.getBalance(accountId: keluargaId), 100000);
    expect(await db.getBalance(), 0); // gabungan tetap

    final legs = await transferLegs(db, g);
    expect(legs, hasLength(2));
    expect(legs.first.isExpense, isTrue); // kaki keluar dulu
    expect(legs.last.isExpense, isFalse); // lalu kaki masuk
    expect(legs.first.note, contains('uang belanja'));
  });

  test('transfer netral di totals + pie + budget-spent', () async {
    await insertTransfer(
      db,
      fromAccountId: utamaId,
      toAccountId: keluargaId,
      amount: 100000,
      date: DateTime(2026, 10, 10, 12),
      note: '',
    );
    final (m, k) = await db.getTotals(f(), t());
    expect((m, k), (0, 0)); // TAK kembung
    expect(await db.totalsByCategory(f(), t(), true), isEmpty);
    expect(await db.totalsByCategory(f(), t(), false), isEmpty);
  });

  test('validasi: dompet sama & nominal 0 & dompet hilang ditolak', () async {
    expect(
      () => insertTransfer(
        db,
        fromAccountId: utamaId,
        toAccountId: utamaId,
        amount: 1000,
        date: DateTime(2026, 10, 10),
        note: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => insertTransfer(
        db,
        fromAccountId: utamaId,
        toAccountId: keluargaId,
        amount: 0,
        date: DateTime(2026, 10, 10),
        note: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => insertTransfer(
        db,
        fromAccountId: 999999,
        toAccountId: keluargaId,
        amount: 1000,
        date: DateTime(2026, 10, 10),
        note: '',
      ),
      throwsArgumentError,
    );
    expect(await db.getBalance(), 0); // tak ada kaki yatim
  });

  test('hapus transfer → kedua kaki hilang, saldo pulih', () async {
    final g = await insertTransfer(
      db,
      fromAccountId: utamaId,
      toAccountId: keluargaId,
      amount: 75000,
      date: DateTime(2026, 10, 10, 12),
      note: '',
    );
    await deleteTransfer(db, g);
    expect(await transferLegs(db, g), isEmpty);
    expect(await db.getBalance(accountId: utamaId), 0);
    expect(await db.getBalance(accountId: keluargaId), 0);
    // Tombstone tidak boleh membuat dompet kosong jadi tak bisa dihapus.
    expect(await accountDeletable(db, keluargaId), isTrue);
  });

  test('aturan hapus dompet: berisi = arsip, kosong = hapus', () async {
    // Keluarga masih kosong → boleh hapus.
    expect(await accountDeletable(db, keluargaId), isTrue);
    // Isi via transfer → tak boleh hapus.
    await insertTransfer(
      db,
      fromAccountId: utamaId,
      toAccountId: keluargaId,
      amount: 10000,
      date: DateTime(2026, 10, 10, 12),
      note: '',
    );
    expect(await accountDeletable(db, keluargaId), isFalse);
    expect(() => deleteAccount(db, keluargaId), throwsArgumentError);
    // Arsip jalan; dompet hilang dari accountsProvider tapi saldo utuh.
    await archiveAccount(db, keluargaId);
    final acc = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(keluargaId))).getSingle();
    expect(acc.isArchived, isTrue);
    expect(await db.getBalance(), 0);
  });
}
