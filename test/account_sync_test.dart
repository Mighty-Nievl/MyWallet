// Round-trip sync dompet v1.25 (Fase 4): akun + transaksi + transfer
// antar dua DB in-memory lewat txToMap/parseRemoteTx/accountToMap/
// parseRemoteAccount/upsertLocal* — tanpa Firebase.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/sync_engine.dart';
import 'package:mywallet/data/sync_meta.dart';

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
        AccountsCompanion(
          name: const Value('Dompetku'),
          openingBalance: const Value(250000),
          isShared: const Value(true),
        ),
      );
      final famId = await a
          .into(a.accounts)
          .insert(
            AccountsCompanion.insert(
              name: 'Keluarga',
              isShared: const Value(true),
            ),
          );

      // Push manual: accountToMap → parseRemoteAccount → upsertLocalAccount.
      for (final acc in await pushableAccounts(a)) {
        final map = accountToMap(acc, 'hid', 'uid');
        // v1.36.2: saldo awal ikut sync; angka turunan tetap tidak.
        expect(map['openingBalance'], isA<int>());
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
      expect(renamed.openingBalance, 250000);

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
        .insert(
          AccountsCompanion.insert(
            name: 'Keluarga',
            isShared: const Value(true),
          ),
        );
    await (a.update(a.accounts)..where((t) => t.id.equals(utamaA.id))).write(
      AccountsCompanion(
        isShared: const Value(true),
        updatedAt: Value(syncNow()),
      ),
    );

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
    expect(await b.getTotals(epoch, jauh), (0, 0)); // totals tak kembung
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

  test('sortOrder ikut push + pull (reorder sync antar-HP, v1.29)', () async {
    final a = await _memDb();
    addTearDown(a.close);
    final acc = (await a.select(a.accounts).get()).single;
    await (a.update(a.accounts)..where((t) => t.id.equals(acc.id))).write(
      AccountsCompanion(sortOrder: const Value(7), updatedAt: Value(syncNow())),
    );
    final fresh = await (a.select(
      a.accounts,
    )..where((t) => t.id.equals(acc.id))).getSingle();
    final m = accountToMap(fresh, 'hid', 'uid');
    expect(m['sortOrder'], 7);
    final parsed = parseRemoteAccount(m);
    expect(parsed, isNotNull);
    expect(parsed!.sortOrder, 7);
    // Pull ke DB kedua: sortOrder tersimpan lokal.
    final b = await _memDb();
    addTearDown(b.close);
    await upsertLocalAccount(b, parsed, 'hid');
    final rows = await b.select(b.accounts).get();
    final got = rows.firstWhere((x) => x.uuid == fresh.uuid);
    expect(got.sortOrder, 7);
  });

  test(
    'v1.36.2 privasi: hanya dompet isShared + transaksinya yang push',
    () async {
      final a = await _memDb();
      addTearDown(a.close);

      final utama = (await a.select(a.accounts).get()).firstWhere(
        (x) => x.name == 'Utama',
      );
      final keluargaId = await a
          .into(a.accounts)
          .insert(
            AccountsCompanion.insert(
              name: 'Keluarga',
              isShared: const Value(true),
            ),
          );
      final keluarga = (await (a.select(
        a.accounts,
      )..where((x) => x.id.equals(keluargaId))).getSingle());

      await a
          .into(a.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 10000,
              isExpense: const Value(true),
              date: DateTime(2026, 10, 10),
              accountId: Value(utama.id),
              accountUuid: Value(utama.uuid),
            ),
          );
      await a
          .into(a.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: 20000,
              isExpense: const Value(false),
              date: DateTime(2026, 10, 11),
              accountId: Value(keluargaId),
              accountUuid: Value(keluarga.uuid),
            ),
          );

      final accs = await pushableAccounts(a);
      expect(accs.map((x) => x.name), ['Keluarga']);
      final txs = await pushableTx(a);
      expect(txs, hasLength(1));
      expect(txs.single.accountUuid, keluarga.uuid);
    },
  );

  test('v1.36.2 privasi: dokumen pribadi tidak di-pull ke HP baru', () async {
    final b = await _memDb();
    addTearDown(b.close);

    final pribadi = parseRemoteAccount({
      'uuid': 'akun-pribadi',
      'name': 'Rahasia',
      'isShared': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    })!;
    expect(await shouldPullAccount(b, pribadi), isFalse);

    final txPribadi = parseRemoteTx({
      'uuid': 'tx-pribadi',
      'amount': 50000,
      'isExpense': true,
      'date': DateTime.now().millisecondsSinceEpoch,
      'note': 'pribadi',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'accountUuid': 'akun-pribadi',
    })!;
    expect(pullableTx(txPribadi, {'akun-keluarga'}), isFalse);
    expect(
      pullableTx(
        parseRemoteTx({
          'uuid': 'tx-keluarga',
          'amount': 50000,
          'isExpense': true,
          'date': DateTime.now().millisecondsSinceEpoch,
          'note': 'keluarga',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'accountUuid': 'akun-keluarga',
        })!,
        {'akun-keluarga'},
      ),
      isTrue,
    );
    expect(
      pullableTx(
        parseRemoteTx({
          'uuid': 'tx-tanpa-dompet',
          'amount': 50000,
          'isExpense': true,
          'date': DateTime.now().millisecondsSinceEpoch,
          'note': 'lama',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        })!,
        {'akun-keluarga'},
      ),
      isFalse,
    );
  });
}
