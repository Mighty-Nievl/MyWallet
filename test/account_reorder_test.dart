import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/account_actions.dart';
import 'package:mywallet/data/database.dart';

Future<List<Account>> _ordered(AppDatabase db) =>
    (db.select(db.accounts)
          ..orderBy([
            (a) => OrderingTerm.asc(a.sortOrder),
            (a) => OrderingTerm.asc(a.name),
          ]))
        .get();

void main() {
  test('reorderAccounts menulis sortOrder sesuai urutan', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.backfillAccounts();
    final utama = (await db.select(
      db.accounts,
    ).get()).firstWhere((a) => a.name == 'Utama');
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'B'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'A'));
    final all = await db.select(db.accounts).get();
    expect(all.length, 3);
    final b = all.firstWhere((a) => a.name == 'B');
    final a = all.firstWhere((a) => a.name == 'A');
    await reorderAccounts(db, [a.id, b.id, utama.id]);
    final names = (await _ordered(db)).map((a) => a.name).toList();
    expect(names, ['A', 'B', 'Utama']);
  });

  test('reorderAccounts abaikan id tak dikenal', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.backfillAccounts();
    await reorderAccounts(db, [999999]);
    final list = await db.select(db.accounts).get();
    expect(list.length, 1);
  });
}
