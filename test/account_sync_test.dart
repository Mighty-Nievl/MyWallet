// Round-trip sync dompet v1.25 (Fase 4): akun + transaksi + transfer
// antar dua DB in-memory lewat txToMap/parseRemoteTx/accountToMap/
// parseRemoteAccount/upsertLocal* — tanpa Firebase.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/sync_engine.dart';

Future<AppDatabase> _memDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.backfillAccounts();
  return db;
}

void main() {
  test(
    'sync akun: push → pull merekonstruksi dompet beda id (v1.25)',
    () async {
      final a = await _memDb();
      final b = await _memDb();
      addTearDown(a.close);
      addTearDown(b.close);

      // HP-A: rename Utama lokal + tambah Keluarga.
      final utamaA = (await a.select(a.accounts).get()).firstWhere(
        (x) => x.name == 'Utama',
      );
      await (a.update(a.accounts)..where((t) => t.id.equals(utamaA.id))).write(
        const AccountsCompanion(name: Value('Dompetku')),
      );
      final famId = await a
          .into(a.accounts)
          .insert(AccountsCompanion.insert(name: 'Keluarga'));

      // Push manual: accountToMap → parseRemoteAccount → upsertLocalAccount.
      for (final acc in await pushableAccounts(a)) {
        final map = accountToMap(acc, 'hid', 'uid');
        // Saldo TIDAK ikut sync (anti konflik angka).
        expect(map.containsKey('openingBalance'), isFalse);
        expect(map.containsKey('amount'), isFalse);
        final r = parseRemoteAccount(map)!;
        await upsertLocalAccount(b, r, 'hid');
      }

      final namesB = (await b.select(b.accounts).get())
          .map((x) => x.name)
          .toSet();
      expect(namesB, containsAll({'Utama', 'Dompetku', 'Keluarga'}));
      // Rename LWW: uuid Utama sama → nama baru menang di HP-B.
      final renamed = (await b.select(b.accounts).get()).firstWhere(
        (x) => x.name == 'Dompetku',
      );
      final utamaA2 = (await a.select(a.accounts).get()).firstWhere(
        (x) => x.name == 'Dompetku',
      );
      expect(renamed.uuid, utamaA2.uuid);

      // Transaksi milik Keluarga di HP-A → pull di HP-B → accountId
      // teresolusi ke Keluarga LOKAL HP-B (id boleh beda).
      final famAUuid = (await (a.select(
        a.accounts,
      )..where((t) => t.id.equals(famId))).getSingle()).uuid!;
      final famBUuid = (await (b.select(
        b.accounts,
      )..where((t) => t.name.equals('Keluarga'))).getSingle()).uuid;
      expect(famBUuid, famAUuid); // uuid = identitas lintas HP
      expect(
        (await (b.select(
          b.accounts,
        )..where((t) => t.name.equals('Keluarga'))).getSingle()).id,
        isNot(famId), // id lokal boleh beda — resolusi pakai uuid
        reason: 'id int lokal tidak stabil antar-HP',
      );
    },
  );

  test('sync tx: accountUuid + transferId merambat (v1.25)', () async {
    final a = await _memDb();
    final b = await _memDb();
    addTearDown(a.close);
    addTearDown(b.close);

    final utamaA = (await a.select(a.accounts).get()).firstWhere(
      (x) => x.name == 'Utama',
    );
    final famId = await a
        .into(a.accounts)
        .insert(AccountsCompanion.insert(name: 'Keluarga'));

    // Transfer 50rb Utama → Keluarga di HP-A (2 kaki, 1 grup).
    await insertTransfer(
      a,
      fromAccountId: utamaA.id,
      toAccountId: famId,
      amount: 50000,
      date: DateTime.now(),
      note: 'test',
    );

    // Push akun dulu (urutan service), lalu transaksi.
    for (final acc in await pushableAccounts(a)) {
      await upsertLocalAccount(
        b,
        parseRemoteAccount(accountToMap(acc, 'hid', 'uid'))!,
        'hid',
      );
    }
    final txs = await pushableTx(a);
    expect(txs, hasLength(2)); // kaki transfer ikut push (dokumen biasa)
    for (final t in txs) {
      final map = txToMap(t, 'hid', 'uid');
      expect(map['transferId'], isNotNull);
      expect(map['accountUuid'], isNotNull);
      await upsertLocalTx(b, parseRemoteTx(map)!, 'hid');
    }

    // HP-B: 2 kaki masuk, grup SAMA, netralitas terjaga.
    final bTxs = await b.select(b.transactions).get();
    expect(bTxs, hasLength(2));
    expect(bTxs.map((t) => t.transferId).toSet(), hasLength(1));
    expect(await b.getBalance(), 0); // gabungan netral
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final jauh = DateTime.now().add(const Duration(days: 1));
    expect(
      await b.getTotals(epoch, jauh),
      (0, 0),
    ); // totals tak kembung
    final famB = (await (b.select(
      b.accounts,
    )..where((t) => t.name.equals('Keluarga'))).getSingle()).id;
    // Kaki masuk teresolusi ke Keluarga lokal HP-B.
    final kakiMasuk = bTxs.firstWhere((t) => !t.isExpense);
    expect(kakiMasuk.accountId, famB);
  });

  test(
    'sync defensif: akun tak dikenal → null ikut gabungan (v1.25)',
    () async {
      final b = await _memDb();
      addTearDown(b.close);
      // Dokumen nyasar (dompet belum sync) → tx tetap masuk, accountId null.
      final r = parseRemoteTx({
        'uuid': 'tx-yatim',
        'amount': 10000,
        'isExpense': true,
        'date': DateTime.now().millisecondsSinceEpoch,
        'note': 'yatim',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'accountUuid': 'uuid-tak-ada',
      })!;
      expect(await upsertLocalTx(b, r, 'hid'), isTrue);
      final row = (await b.select(b.transactions).get()).single;
      expect(row.accountId, isNull);
      expect(row.accountUuid, 'uuid-tak-ada'); // tersimpan utk resolusi nanti
      // Ikut gabungan: tak hilang dari laporan.
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final jauh = DateTime.now().add(const Duration(days: 1));
      expect((await b.getTotals(epoch, jauh)).$2, 10000);
    },
  );
}
