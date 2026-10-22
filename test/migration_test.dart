// v1.38.5 — migrasi & seed diuji, bukan diasumsikan.
//
// Sampai v1.38.4 tidak ada satu pun test yang menjalankan `onUpgrade`.
// Artinya: seluruh 32 operasi migrasi di `database.dart` belum pernah
// dieksekusi kecuali di HP user, pada data user. Untuk app yang menyimpan
// uang, itu risiko yang tidak kelihatan sampai ada yang kehilangan data.
//
// Yang diuji di sini:
// 1. **v4 → v5**: DB berskema v4 (tanpa `is_shared`) dibuka; drift
//    menjalankan `onUpgrade`; baris lama harus utuh dan otomatis
//    `isShared = false` (privat), bukan hilang.
// 2. **onCreate v5**: instalasi baru dapat kategori bawaan + dompet
//    "Utama" — ini regresi v1.36.2 ("Belum ada dompet" di instalasi baru)
//    yang dulu tidak ada penjaganya.
//
// Batasan yang jujur: rantai penuh v1 → v5 tidak diputar ulang di sini
// (butuh skema v1..v4 utuh, ratusan baris SQL). Yang dijaga adalah
// langkah terakhir, karena itulah yang dijalankan user yang upgrade dari
// versi rilis sebelumnya. Untuk rantai penuh, jalan yang benar adalah
// `drift_dev schema dump` + test bertahap — belum ada di repo ini.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/tables.dart';

/// Skema `accounts` persis versi 4: semua kolom v5 kecuali `is_shared`.
const _accountsV4 = '''
CREATE TABLE accounts (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT '💼',
  opening_balance INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  uuid TEXT,
  updated_at INTEGER,
  deleted_at INTEGER,
  household_id TEXT
);
''';

void main() {
  test('v4 → v5: kolom is_shared ditambah, data lama utuh & privat', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) async {
          raw.execute(_accountsV4);
          raw.execute(
            "INSERT INTO accounts (name, opening_balance) "
            "VALUES ('Dompet Lama', 250000)",
          );
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(db.close);

    // Query pertama memicu pembukaan + onUpgrade.
    final rows = await db.select(db.accounts).get();

    expect(rows, hasLength(1), reason: 'baris lama tidak boleh hilang');
    expect(rows.single.name, 'Dompet Lama');
    expect(rows.single.openingBalance, 250000);
    expect(
      rows.single.isShared,
      isFalse,
      reason: 'default v1.32: dompet lama tetap pribadi, bukan tiba-tiba dibagi',
    );
    expect(rows.single.id, 1, reason: 'PK tidak boleh berubah');
  });

  test('onCreate v5: kategori bawaan + dompet Utama ada di instalasi baru', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cats = await db.select(db.categories).get();
    expect(
      cats.map((c) => c.name).toSet(),
      defaultCategories.map((c) => c['name'] as String).toSet(),
      reason: 'seed kategori harus persis defaultCategories',
    );

    final accounts = await db.select(db.accounts).get();
    expect(
      accounts.map((a) => a.name),
      contains('Utama'),
      reason: 'regresi v1.36.2: instalasi baru tanpa dompet = user mentok',
    );
    expect(accounts.single.isShared, isFalse);
  });
}
