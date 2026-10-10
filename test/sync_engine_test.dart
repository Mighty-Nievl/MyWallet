import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/sync_engine.dart';
import 'package:mywallet/data/sync_meta.dart';

/// Test sync engine MURNI Fase 2 (v1.19 beta) — TANPA network.
///
/// Strategi: 2 db in-memory = 2 HP (A dan B). Simulasi push/pull
/// dilakukan di level Map (catToMap/txToMap → parseRemote* → upsert*),
/// persis urutan yang dipakai `SyncService` (bedanya service lewat
/// Firestore; logika LWW/upsert/resolusi SAMA dan di sinilah bug
/// sync biasanya sembunyi).
void main() {
  late AppDatabase a;
  late AppDatabase b;

  setUp(() async {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    await a.select(a.categories).get(); // picu onCreate + seed
    await b.select(b.categories).get();
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  group('serialisasi kategori', () {
    test('catToMap → parseRemoteCat round-trip', () async {
      final cat = (await a.select(a.categories).get()).first;
      final m = catToMap(cat, 'H1', 'U1');
      expect(m['uuid'], cat.uuid);
      expect(m['householdId'], 'H1');
      expect(m['updatedBy'], 'U1');
      final r = parseRemoteCat(m)!;
      expect(r.uuid, cat.uuid);
      expect(r.name, cat.name);
      expect(r.updatedAt, cat.updatedAt);
    });

    test('parseRemoteCat sampah → null (skip, bukan crash)', () {
      expect(parseRemoteCat({}), isNull);
      expect(parseRemoteCat({'uuid': ''}), isNull);
    });
  });

  group('serialisasi transaksi', () {
    test('txToMap → parseRemoteTx round-trip', () async {
      final cat = (await a.select(a.categories).get()).first;
      final id = await a.into(a.transactions).insert(
            TransactionsCompanion.insert(
              amount: 25000,
              isExpense: const Value(true),
              categoryId: Value(cat.id),
              categoryUuid: Value(cat.uuid),
              date: DateTime(2026, 10, 10),
              note: const Value('kopi'),
            ),
          );
      final t = await (a.select(a.transactions)
            ..where((x) => x.id.equals(id)))
          .getSingle();
      final m = txToMap(t, 'H1', 'U1');
      expect(m['uuid'], t.uuid);
      expect(m['categoryUuid'], cat.uuid);
      final r = parseRemoteTx(m)!;
      expect(r.uuid, t.uuid);
      expect(r.amount, 25000);
      expect(r.note, 'kopi');
    });

    test('cermin utang dikenali → jangan push', () async {
      final debtId = await a.into(a.debts).insert(
            DebtsCompanion.insert(
              name: 'Budi',
              total: 100000,
              date: DateTime(2026, 10, 1),
            ),
          );
      await a.into(a.transactions).insert(
            TransactionsCompanion.insert(
              amount: 100000,
              isExpense: const Value(false),
              date: DateTime(2026, 10, 1),
              debtId: Value(debtId),
            ),
          );
      final all = await a.select(a.transactions).get();
      expect(all, hasLength(1));
      expect(isMirrorTx(all.first), isTrue);
      expect(await pushableTx(a), isEmpty);
    });
  });

  group('LWW + upsert antar-HP', () {
    test('remote menang bila lebih baru; kalah bila sama/tua', () {
      final base = DateTime(2026, 10, 10, 12);
      expect(remoteWins(null, base), isTrue);
      expect(
          remoteWins(base, base.add(const Duration(seconds: 1))), isTrue);
      expect(remoteWins(base, base), isFalse); // anti flip-flop
      expect(
          remoteWins(base, base.subtract(const Duration(seconds: 1))),
          isFalse);
    });

    test('kategori A → B: insert lalu update-menang', () async {
      final catA = (await a.select(a.categories).get()).first;
      final m1 = catToMap(catA, 'H1', 'UA');
      final r1 = parseRemoteCat(m1)!;
      // Samakan uuid B dengan A agar jadi "baris yang sama".
      final catB = (await b.select(b.categories).get()).firstWhere(
          (c) => c.uuid != catA.uuid,
          orElse: () => throw 'seed kurang');
      await (b.update(b.categories)..where((c) => c.id.equals(catB.id)))
          .write(CategoriesCompanion(
        uuid: Value(catA.uuid),
        updatedAt: Value(DateTime(2020, 1, 1)),
      ));
      expect(await upsertLocalCat(b, r1, 'H1'), isTrue);
      final got = await (b.select(b.categories)
            ..where((c) => c.uuid.equals(catA.uuid!)))
          .getSingle();
      expect(got.name, catA.name);
      // Remote tua → ditolak.
      final stale = (
        uuid: catA.uuid!,
        name: 'Jadul',
        icon: '📦',
        isExpense: true,
        updatedAt: DateTime(2020, 1, 1),
        deletedAt: null,
      );
      expect(await upsertLocalCat(b, stale, 'H1'), isFalse);
      final still = await (b.select(b.categories)
            ..where((c) => c.uuid.equals(catA.uuid!)))
          .getSingle();
      expect(still.name, catA.name);
    });

    test('transaksi A → B: categoryUuid teresolusi ke id lokal B', () async {
      // B bikin kategori dengan uuid SAMA seperti kategori A.
      final catA = (await a.select(a.categories).get()).first;
      final catB = (await b.select(b.categories).get()).first;
      await (b.update(b.categories)..where((c) => c.id.equals(catB.id)))
          .write(CategoriesCompanion(
        uuid: Value(catA.uuid),
        name: Value(catA.name),
      ));
      final txId = await a.into(a.transactions).insert(
            TransactionsCompanion.insert(
              amount: 42000,
              isExpense: const Value(true),
              categoryId: Value(catA.id),
              categoryUuid: Value(catA.uuid),
              date: DateTime(2026, 10, 11),
              note: const Value('sync-test'),
            ),
          );
      final t = await (a.select(a.transactions)
            ..where((x) => x.id.equals(txId)))
          .getSingle();
      final r = parseRemoteTx(txToMap(t, 'H1', 'UA'))!;
      expect(await upsertLocalTx(b, r, 'H1'), isTrue);
      final got = await (b.select(b.transactions)
            ..where((x) => x.uuid.equals(t.uuid!)))
          .getSingle();
      expect(got.amount, 42000);
      expect(got.categoryId, catB.id); // teresolusi ke id B
      expect(got.categoryUuid, catA.uuid);
      expect(got.householdId, 'H1');
    });

    test('tombstone hapus merambat (deletedAt menimpa hidup)', () async {
      final catA = (await a.select(a.categories).get()).first;
      final catB = (await b.select(b.categories).get()).first;
      await (b.update(b.categories)..where((c) => c.id.equals(catB.id)))
          .write(CategoriesCompanion(
        uuid: Value(catA.uuid),
        updatedAt: Value(DateTime(2020, 1, 1)),
      ));
      final tomb = (
        uuid: catA.uuid!,
        name: catA.name,
        icon: catA.icon,
        isExpense: catA.isExpense,
        updatedAt: syncNow(),
        deletedAt: syncNow(),
      );
      expect(await upsertLocalCat(b, tomb, 'H1'), isTrue);
      final got = await (b.select(b.categories)
            ..where((c) => c.uuid.equals(catA.uuid!)))
          .getSingle();
      expect(got.deletedAt, isNotNull);
    });

    test('stamp push isi householdId tanpa ubah uuid', () async {
      final cat = (await a.select(a.categories).get()).first;
      final before = cat.uuid!;
      await stampPushedCats(a, [cat.id], 'H-BRAM');
      final after = await (a.select(a.categories)
            ..where((c) => c.id.equals(cat.id)))
          .getSingle();
      expect(after.householdId, 'H-BRAM');
      expect(after.uuid, before);
    });
  });
}
