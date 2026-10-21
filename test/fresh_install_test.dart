// Regression v1.36.2: instalasi baru langsung punya dompet "Utama",
// jadi pengguna baru tidak mentok "Belum ada dompet".
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';

void main() {
  test('db baru langsung punya dompet Utama (v1.36.2)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.categories).get(); // picu onCreate + seed

    final accs = await db.select(db.accounts).get();
    expect(accs, hasLength(1));
    expect(accs.single.name, 'Utama');
    expect(accs.single.uuid, isNotNull);
    // Kategori bawaan tetap ikut.
    expect(await db.select(db.categories).get(), isNotEmpty);
  });
}
