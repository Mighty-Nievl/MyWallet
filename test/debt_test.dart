import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/debt_actions.dart';
import 'package:mywallet/data/providers.dart';

/// Test manajer utang-piutang (v1.15, skema v2) — cermin saldo otomatis.
///
/// Strategi ala budget_test: fungsi inti langsung dengan db in-memory
/// (tanpa ProviderContainer/widget):
/// - insert/update/delete via debt_actions (AppDatabase langsung)
/// - baca via fetchDebts (logika yang dipakai debtsProvider)
/// - saldo via getBalance (query lama — bukti cermin ikut)
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> txCount() async =>
      (await db.select(db.transactions).get()).length;

  Future<List<Transaction>> txsOfDebt(int debtId) async =>
      (db.select(db.transactions)..where((t) => t.debtId.equals(debtId)))
          .get();

  group('catat utang (opsi B: cermin pemasukan)', () {
    test('utang 1jt → saldo +1jt + 1 cermin masuk', () async {
      final before = await db.getBalance();
      final id = await insertDebt(db,
          name: 'Budi',
          isDebt: true,
          total: 1000000,
          date: DateTime(2026, 10, 1),
          dueDate: null,
          note: '');
      expect(id, greaterThan(0));
      expect(await db.getBalance(), before + 1000000);

      final txs = await txsOfDebt(id);
      expect(txs, hasLength(1));
      expect(txs.single.amount, 1000000);
      expect(txs.single.isExpense, isFalse); // MASUK
      expect(txs.single.debtPaymentId, isNull);
      expect(txs.single.note, contains('Budi'));
    });

    test('piutang 500rb → saldo −500rb + 1 cermin keluar', () async {
      final before = await db.getBalance();
      final id = await insertDebt(db,
          name: 'Siti',
          isDebt: false,
          total: 500000,
          date: DateTime(2026, 10, 2),
          dueDate: DateTime(2026, 11, 2),
          note: 'modal');
      expect(await db.getBalance(), before - 500000);

      final txs = await txsOfDebt(id);
      expect(txs, hasLength(1));
      expect(txs.single.isExpense, isTrue); // KELUAR
      expect(txs.single.note, contains('Siti'));
    });

    test('validasi: nama kosong & total 0 ditolak', () async {
      expect(
        () => insertDebt(db,
            name: '  ', isDebt: true, total: 1000,
            date: DateTime(2026, 10, 1), dueDate: null, note: ''),
        throwsArgumentError,
      );
      expect(
        () => insertDebt(db,
            name: 'X', isDebt: true, total: 0,
            date: DateTime(2026, 10, 1), dueDate: null, note: ''),
        throwsArgumentError,
      );
      expect(await txCount(), 0); // tidak ada cermin yatim
    });
  });

  group('cicilan (parsial berkali-kali)', () {
    test('bayar utang 2x → saldo berkurang bertahap + lunas', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      final saldoAwal = await db.getBalance();

      await insertDebtPayment(db,
          debtId: id, amount: 400000,
          date: DateTime(2026, 10, 5), note: '');
      expect(await debtPaidOf(db, id), 400000);
      expect(await db.getBalance(), saldoAwal - 400000);

      await insertDebtPayment(db,
          debtId: id, amount: 600000,
          date: DateTime(2026, 10, 6), note: '');
      expect(await debtPaidOf(db, id), 1000000);
      expect(await db.getBalance(), saldoAwal - 1000000);

      // Cermin cicilan = pengeluaran (bayar utang = keluar).
      final txs = await txsOfDebt(id);
      expect(txs, hasLength(3)); // 1 pokok + 2 cicilan
      final cicilan = txs.where((t) => t.debtPaymentId != null).toList();
      expect(cicilan, hasLength(2));
      expect(cicilan.every((t) => t.isExpense), isTrue);
    });

    test('terima piutang → saldo + (pemasukan)', () async {
      final id = await insertDebt(db,
          name: 'Siti', isDebt: false, total: 500000,
          date: DateTime(2026, 10, 2), dueDate: null, note: '');
      final saldoAwal = await db.getBalance();
      await insertDebtPayment(db,
          debtId: id, amount: 200000,
          date: DateTime(2026, 10, 3), note: '');
      expect(await db.getBalance(), saldoAwal + 200000);
      final txs = await txsOfDebt(id);
      final cicilan = txs.where((t) => t.debtPaymentId != null).toList();
      expect(cicilan.single.isExpense, isFalse); // MASUK
    });

    test('overpay ditolak — tidak ada cermin yatim', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 100000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      final n0 = await txCount();
      expect(
        () => insertDebtPayment(db,
            debtId: id, amount: 100001,
            date: DateTime(2026, 10, 5), note: ''),
        throwsA(isA<DebtOverpayException>()),
      );
      expect(await txCount(), n0);
      expect(await debtPaidOf(db, id), 0);
    });

    test('pas lunas boleh, lebih 1 rupiah pun tidak', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 100000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: id, amount: 99999,
          date: DateTime(2026, 10, 5), note: '');
      await insertDebtPayment(db,
          debtId: id, amount: 1,
          date: DateTime(2026, 10, 6), note: 'pelunasan');
      expect(await debtPaidOf(db, id), 100000);
    });

    test('nominal 0/negatif ditolak', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 100000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      expect(
        () => insertDebtPayment(db,
            debtId: id, amount: 0,
            date: DateTime(2026, 10, 5), note: ''),
        throwsArgumentError,
      );
    });
  });

  group('fetchDebts (logika debtsProvider)', () {
    test('kosong → list kosong', () async {
      expect(await fetchDebts(db), isEmpty);
    });

    test('progress + done + urutan: aktif dulu, tempo dekat dulu', () async {
      final lunasId = await insertDebt(db,
          name: 'Zaki', isDebt: true, total: 100000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: lunasId, amount: 100000,
          date: DateTime(2026, 10, 2), note: '');

      await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 12, 31), note: '');
      final andiId = await insertDebt(db,
          name: 'Andi', isDebt: false, total: 500000,
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 10, 20), note: '');
      await insertDebtPayment(db,
          debtId: andiId, amount: 200000,
          date: DateTime(2026, 10, 3), note: '');

      final list = await fetchDebts(db);
      expect(list, hasLength(3));
      // Aktif dulu (Andi tempo Okt, Budi tempo Des), lunas paling akhir.
      expect(list[0].debt.name, 'Andi');
      expect(list[0].paid, 200000);
      expect(list[0].remaining, 300000);
      expect(list[0].done, isFalse);
      expect(list[1].debt.name, 'Budi');
      expect(list[2].debt.name, 'Zaki');
      expect(list[2].done, isTrue);
    });
  });

  group('ubah & hapus', () {
    test('ubah total sinkron cermin pokok (cicilan tetap)', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: id, amount: 200000,
          date: DateTime(2026, 10, 5), note: '');
      final saldoSebelum = await db.getBalance();

      await updateDebt(db,
          id: id, name: 'Budi H.', total: 1200000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      // Saldo naik 200rb (pokok 1jt → 1,2jt), cicilan tidak berubah.
      expect(await db.getBalance(), saldoSebelum + 200000);
      expect(await debtPaidOf(db, id), 200000);
      final list = await fetchDebts(db);
      expect(list.single.remaining, 1000000);
    });

    test('total baru < sudah dibayar ditolak', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: id, amount: 600000,
          date: DateTime(2026, 10, 5), note: '');
      expect(
        () => updateDebt(db,
            id: id, name: 'Budi', total: 500000,
            date: DateTime(2026, 10, 1), dueDate: null, note: ''),
        throwsA(isA<DebtInvalidTotalException>()),
      );
    });

    test('hapus utang → cicilan + SEMUA cermin ikut hilang', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: id, amount: 200000,
          date: DateTime(2026, 10, 5), note: '');
      final saldoSebelumHapus = await db.getBalance();
      // Saldo sekarang = +1jt −200rb = +800rb vs awal.
      await deleteDebt(db, id);
      // Setelah hapus, efek utang hilang total dari saldo.
      expect(await db.getBalance(), saldoSebelumHapus - 800000);
      expect(await fetchDebts(db), isEmpty);
      expect(await txsOfDebt(id), isEmpty);
      expect(
          await (db.select(db.debtPayments)
                ..where((p) => p.debtId.equals(id)))
              .get(),
          isEmpty);
    });

    test('hapus 1 cicilan → cerminnya ikut, pokok tetap', () async {
      final id = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      final payId = await insertDebtPayment(db,
          debtId: id, amount: 200000,
          date: DateTime(2026, 10, 5), note: '');
      final saldoSebelum = await db.getBalance();
      await deleteDebtPayment(db, payId);
      // Hapus bayar-utang 200rb (= pengeluaran) → saldo naik 200rb.
      expect(await db.getBalance(), saldoSebelum + 200000);
      expect(await debtPaidOf(db, id), 0);
      expect((await txsOfDebt(id)), hasLength(1)); // pokok tetap
    });
  });

  group('debtSummary (kartu Beranda)', () {
    test('hanya sisa aktif; lunas tidak dihitung', () async {
      final a = await insertDebt(db,
          name: 'Budi', isDebt: true, total: 1000000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: a, amount: 300000,
          date: DateTime(2026, 10, 5), note: '');
      final b = await insertDebt(db,
          name: 'Siti', isDebt: false, total: 500000,
          date: DateTime(2026, 10, 1), dueDate: null, note: '');
      await insertDebtPayment(db,
          debtId: b, amount: 500000,
          date: DateTime(2026, 10, 6), note: 'lunas');

      // Hitung manual ala debtSummaryProvider.
      final list = await fetchDebts(db);
      var utang = 0;
      var piutang = 0;
      for (final e in list) {
        if (e.done) continue;
        if (e.debt.isDebt) {
          utang += e.remaining;
        } else {
          piutang += e.remaining;
        }
      }
      expect(utang, 700000);
      expect(piutang, 0); // Siti lunas → tidak dihitung
    });
  });
}
