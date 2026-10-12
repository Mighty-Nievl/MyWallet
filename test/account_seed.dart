// Helper seed sadar-dompet (v1.25) — SATU sumber untuk semua test.
//
// Masalah: insert transaksi v1.25 butuh accountId; test lama insert
// mentah (NULL) → baris hilang dari filter dompet + angka gabungan
// tetap benar tapi per-dompet salah. Helper ini backfill "Utama"
// lalu kembalikan id-nya; helper tx() sisipkan otomatis.
//
// Pakai: `final utama = await seedUtama(db);` lalu `accountId: Value(utama)`
// di tiap TransactionsCompanion.insert.
import 'package:drift/native.dart';

import 'package:mywallet/data/database.dart';

/// Backfill dompet "Utama" + kembalikan id-nya.
/// Idempoten (backfillAccounts idempoten) — aman dipanggil tiap setUp.
Future<int> seedUtama(AppDatabase db) async {
  await db.backfillAccounts();
  return (await db.select(db.accounts).get())
      .firstWhere((a) => a.name == 'Utama')
      .id;
}

/// DB in-memory segar + seed kategori + dompet Utama.
/// Untuk unit-test (tanpa widget harness).
Future<(AppDatabase, int)> freshDbWithUtama() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.select(db.categories).get(); // picu onCreate + seed
  final utama = await seedUtama(db);
  return (db, utama);
}
