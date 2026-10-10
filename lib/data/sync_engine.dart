import 'package:drift/drift.dart';

import 'database.dart';
import 'sync_meta.dart';

/// Logika sync MURNI Fase 2 (v1.19, beta) — TANPA Firebase.
///
/// Semua yang butuh network tinggal di `sync_service.dart`. Yang di sini
/// murni + unit-testable dengan db in-memory:
///
/// - Serialisasi baris ↔ Map Firestore (millis int, bukan Timestamp —
///   konversi Timestamp↔millis di service agar file ini bebas plugin).
/// - [remoteWins]: last-write-wins per baris via `updatedAt`.
/// - Upsert lokal per uuid + resolusi `categoryUuid` → `categoryId`.
/// - [isMirrorTx]: cermin utang TIDAK di-push mentah (keputusan roadmap:
///   cermin di-rebuild per-HP di Fase 3; push mentah = ganda saat
///   Fase 3 sync debts). Pull juga men-skip cermin bila ada yang
///   nyasar (tidak ada HP yang push cermin, jadi normalnya nol).
///
/// Koleksi Firestore (lihat `firestore.rules`):
/// - `households/{hid}/cats/{uuid}`: kategori.
/// - `households/{hid}/tx/{uuid}`: transaksi non-cermin.
///
/// Aturan main beta:
/// - Push = SEMUA baris lokal (hidup + terhapus-lembut sebagai tombstone),
///   kecuali cermin utang. Baris yang di-push di-stamp `householdId`.
/// - Pull = full koleksi (skala beta ratusan baris, aman) → upsert LWW.
/// - Soft-delete merambat via `deletedAt`; hapus fisik tidak merambat
///   (actions Fase 2 sudah soft-delete, bukan hapus fisik).

/// Dokumen kategori jarak-jauh (hasil parse defensif).
typedef RemoteCat = ({
  String uuid,
  String name,
  String icon,
  bool isExpense,
  DateTime updatedAt,
  DateTime? deletedAt,
});

/// Dokumen transaksi jarak-jauh.
typedef RemoteTx = ({
  String uuid,
  int amount,
  bool isExpense,
  String? categoryUuid,
  DateTime date,
  String note,
  DateTime createdAt,
  DateTime updatedAt,
  DateTime? deletedAt,
});

DateTime _ms(int? v, DateTime fallback) =>
    v == null ? fallback : DateTime.fromMillisecondsSinceEpoch(v);

// ---------- Serialisasi (lokal → Map push) ----------

/// Map kategori untuk push. Null `updatedAt` lokal (baris pra-backfill,
/// normalnya tidak ada) → jam sekarang agar LWW tetap jalan.
Map<String, dynamic> catToMap(
  Category c,
  String householdId,
  String uid, {
  DateTime? now,
}) {
  final t = now ?? syncNow();
  return {
    'uuid': c.uuid ?? '',
    'name': c.name,
    'icon': c.icon,
    'isExpense': c.isExpense,
    'updatedAt': (c.updatedAt ?? t).millisecondsSinceEpoch,
    if (c.deletedAt != null)
      'deletedAt': c.deletedAt!.millisecondsSinceEpoch,
    'updatedBy': uid,
    'householdId': householdId,
  };
}

/// Map transaksi untuk push (non-cermin — panggil [isMirrorTx] dulu).
Map<String, dynamic> txToMap(
  Transaction t,
  String householdId,
  String uid, {
  DateTime? now,
}) {
  final nowMs = now ?? syncNow();
  return {
    'uuid': t.uuid ?? '',
    'amount': t.amount,
    'isExpense': t.isExpense,
    'categoryUuid': t.categoryUuid,
    'date': t.date.millisecondsSinceEpoch,
    'note': t.note,
    'createdAt': t.createdAt.millisecondsSinceEpoch,
    'updatedAt': (t.updatedAt ?? nowMs).millisecondsSinceEpoch,
    if (t.deletedAt != null)
      'deletedAt': t.deletedAt!.millisecondsSinceEpoch,
    'updatedBy': uid,
    'householdId': householdId,
  };
}

// ---------- Parse defensif (Map pull → record) ----------

/// null = dokumen sampah (tanpa uuid) → skip, bukan crash.
RemoteCat? parseRemoteCat(Map<String, dynamic> m) {
  final uuid = m['uuid'] as String?;
  if (uuid == null || uuid.isEmpty) return null;
  final now = syncNow();
  return (
    uuid: uuid,
    name: (m['name'] as String?) ?? '?',
    icon: (m['icon'] as String?) ?? '📦',
    isExpense: (m['isExpense'] as bool?) ?? true,
    updatedAt: _ms(m['updatedAt'] as int?, now),
    deletedAt: m['deletedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['deletedAt'] as int),
  );
}

RemoteTx? parseRemoteTx(Map<String, dynamic> m) {
  final uuid = m['uuid'] as String?;
  if (uuid == null || uuid.isEmpty) return null;
  final now = syncNow();
  return (
    uuid: uuid,
    amount: (m['amount'] as int?) ?? 0,
    isExpense: (m['isExpense'] as bool?) ?? true,
    categoryUuid: m['categoryUuid'] as String?,
    date: _ms(m['date'] as int?, now),
    note: (m['note'] as String?) ?? '',
    createdAt: _ms(m['createdAt'] as int?, now),
    updatedAt: _ms(m['updatedAt'] as int?, now),
    deletedAt: m['deletedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['deletedAt'] as int),
  );
}

// ---------- LWW ----------

/// true bila dokumen remote MENANG atas baris lokal.
/// Lokal null (pra-backfill) = kalah. Waktu SAMA = lokal menang
/// (anti flip-flop: dua HP konvergen tanpa ping-pong).
bool remoteWins(DateTime? localUpdated, DateTime remoteUpdated) {
  if (localUpdated == null) return true;
  return remoteUpdated.isAfter(localUpdated);
}

// ---------- Upsert lokal (pull) ----------

/// Upsert kategori per uuid. Return true bila berubah (insert/update).
Future<bool> upsertLocalCat(
  AppDatabase db,
  RemoteCat r,
  String householdId,
) async {
  final local = await (db.select(db.categories)
        ..where((c) => c.uuid.equals(r.uuid)))
      .getSingleOrNull();
  if (local == null) {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: r.name,
            icon: Value(r.icon),
            isExpense: Value(r.isExpense),
            uuid: Value(r.uuid),
            updatedAt: Value(r.updatedAt),
            deletedAt: Value(r.deletedAt),
            householdId: Value(householdId),
          ),
        );
    return true;
  }
  if (!remoteWins(local.updatedAt, r.updatedAt)) return false;
  await (db.update(db.categories)..where((c) => c.id.equals(local.id))).write(
        CategoriesCompanion(
          name: Value(r.name),
          icon: Value(r.icon),
          isExpense: Value(r.isExpense),
          updatedAt: Value(r.updatedAt),
          deletedAt: Value(r.deletedAt),
          householdId: Value(householdId),
        ),
      );
  return true;
}

/// Upsert transaksi per uuid + resolusi kategori.
/// `categoryUuid` remote → `categoryId` lokal (cari uuid); tidak ketemu
/// = null (transaksi tetap masuk sebagai "Tanpa kategori", uuid
/// pendamping tetap tersimpan untuk resolusi ulang nanti).
Future<bool> upsertLocalTx(
  AppDatabase db,
  RemoteTx r,
  String householdId,
) async {
  final local = await (db.select(db.transactions)
        ..where((t) => t.uuid.equals(r.uuid)))
      .getSingleOrNull();
  final catId = await _localCategoryId(db, r.categoryUuid);
  if (local == null) {
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: r.amount,
            isExpense: Value(r.isExpense),
            categoryId: Value(catId),
            categoryUuid: Value(r.categoryUuid),
            date: r.date,
            note: Value(r.note),
            createdAt: Value(r.createdAt),
            uuid: Value(r.uuid),
            updatedAt: Value(r.updatedAt),
            deletedAt: Value(r.deletedAt),
            householdId: Value(householdId),
          ),
        );
    return true;
  }
  if (!remoteWins(local.updatedAt, r.updatedAt)) return false;
  await (db.update(db.transactions)..where((t) => t.id.equals(local.id)))
      .write(
    TransactionsCompanion(
      amount: Value(r.amount),
      isExpense: Value(r.isExpense),
      categoryId: Value(catId),
      categoryUuid: Value(r.categoryUuid),
      date: Value(r.date),
      note: Value(r.note),
      updatedAt: Value(r.updatedAt),
      deletedAt: Value(r.deletedAt),
      householdId: Value(householdId),
    ),
  );
  return true;
}

Future<int?> _localCategoryId(AppDatabase db, String? uuid) async {
  if (uuid == null || uuid.isEmpty) return null;
  final cat = await (db.select(db.categories)
        ..where((c) => c.uuid.equals(uuid)))
      .getSingleOrNull();
  return cat?.id;
}

// ---------- Seleksi push ----------

/// true bila transaksi cermin utang (debtId terisi) → JANGAN push mentah.
/// Cermin di-rebuild per-HP di Fase 3 dari debts yang di-sync.
bool isMirrorTx(Transaction t) => t.debtId != null;

/// Semua kategori lokal (hidup + tombstone) untuk push penuh beta.
Future<List<Category>> pushableCats(AppDatabase db) =>
    db.select(db.categories).get();

/// Transaksi non-cermin (hidup + tombstone) untuk push penuh beta.
Future<List<Transaction>> pushableTx(AppDatabase db) async {
  final all = await db.select(db.transactions).get();
  return all.where((t) => !isMirrorTx(t)).toList();
}

/// Stamp `householdId` + pastikan uuid/updatedAt terisi untuk baris yang
/// baru di-push (agar push berikutnya konsisten + query masa depan bisa
/// filter per rumah bila perlu).
Future<void> stampPushedCats(
  AppDatabase db,
  Iterable<int> ids,
  String householdId,
) async {
  final now = syncNow();
  for (final id in ids) {
    final row = await (db.select(db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) continue;
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(
            householdId: Value(householdId),
            uuid: Value(row.uuid ?? newSyncUuid()),
            updatedAt: Value(row.updatedAt ?? now),
          ),
        );
  }
}

Future<void> stampPushedTx(
  AppDatabase db,
  Iterable<int> ids,
  String householdId,
) async {
  final now = syncNow();
  for (final id in ids) {
    final row = await (db.select(db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) continue;
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            householdId: Value(householdId),
            uuid: Value(row.uuid ?? newSyncUuid()),
            updatedAt: Value(row.updatedAt ?? now),
          ),
        );
  }
}
