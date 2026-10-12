// Baseline pra-dompet-ganda (Fase 0, plan v1.25.0).
//
// Mengunci perilaku lama agar drift ketahuan seketika saat migrasi v4:
// - saldo gabungan = SUM seluruh transactions (tanpa filter akun).
// - cermin utang/piutang ikut getBalance + getTotals.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/debt_actions.dart';

void main() {
  late AppDatabase db;
  late int utamaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.categories).get(); // picu onCreate + seed
    await db.backfillAccounts(); // seed dompet Utama (v1.25)
    utamaId = (await db.select(db.accounts).get())
        .firstWhere((a) => a.name == 'Utama')
        .id;
  });

  tearDown(() async {
    await db.close();
  });

  test('baseline: saldo gabungan + cermin utang masuk totals', () async {
    final id = await insertDebt(
      db,
      accountId: utamaId,
      name: 'Budi',
      isDebt: true,
      total: 100000,
      date: DateTime(2026, 10, 1),
      dueDate: null,
      note: '',
    );
    expect(id, greaterThan(0));
    expect(await db.getBalance(), 100000);

    final (masuk, keluar) = await db.getTotals(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31, 23, 59, 59),
    );
    expect(masuk, 100000);
    expect(keluar, 0);
  });

  test('baseline: piutang kurangi saldo + masuk totals keluar', () async {
    await insertDebt(
      db,
      accountId: utamaId,
      name: 'Siti',
      isDebt: false,
      total: 50000,
      date: DateTime(2026, 10, 2),
      dueDate: null,
      note: '',
    );
    expect(await db.getBalance(), -50000);

    final (masuk, keluar) = await db.getTotals(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31, 23, 59, 59),
    );
    expect(masuk, 0);
    expect(keluar, 50000);
  });
}
