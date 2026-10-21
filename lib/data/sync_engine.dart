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
/// - Push = SEMUA kategori lokal + HANYA dompet bertanda `isShared`
///   beserta transaksinya (v1.36.2 — dompet pribadi tidak menyentuh
///   cloud). Cermin utang tidak pernah di-push.
/// - Pull = kategori penuh, dompet yang dishare, dan transaksi milik
///   dompet itu. Dokumen pribadi dari aplikasi versi lama ditolak
///   (kecuali barisnya sudah ada lokal, demi merambatkan toggle OFF).
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

/// Dokumen dompet jarak-jauh (v1.25).
/// v1.36.2: `openingBalance` ikut sync (sebelumnya sengaja tidak —
/// akibatnya saldo antar-HP bisa beda). `int?` = dokumen lama tanpa
/// field tetap menghormati angka lokal. Saldo berjalan tetap dihitung
/// per-HP dari transaksi (anti konflik angka turunan).
/// v1.32: + isShared (toggle keluarga per-dompet).
typedef RemoteAccount = ({
  String uuid,
  String name,
  bool isArchived,
  int sortOrder,
  bool isShared,
  int? openingBalance,
  DateTime updatedAt,
  DateTime? deletedAt,
});

/// Dokumen transaksi jarak-jauh.
///
/// v1.25: + `accountUuid` (dompet pemilik, resolusi → accountId lokal)
/// + `transferId` (grup transfer; kaki transfer di-push sebagai 2
/// dokumen biasa dengan grup SAMA — netralitas terjaga di HP lain via
/// filter `transfer_id IS NULL` yang sama).
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
  String? accountUuid,
  String? transferId,
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
    if (c.deletedAt != null) 'deletedAt': c.deletedAt!.millisecondsSinceEpoch,
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
    if (t.deletedAt != null) 'deletedAt': t.deletedAt!.millisecondsSinceEpoch,
    // v1.25: dompet + grup transfer ikut push (resolusi saat pull).
    if (t.accountUuid != null) 'accountUuid': t.accountUuid,
    if (t.transferId != null) 'transferId': t.transferId,
    'updatedBy': uid,
    'householdId': householdId,
  };
}

/// Map dompet untuk push (v1.25). v1.36.2: `openingBalance` ikut supaya
/// saldo antar-HP tidak berbeda; saldo berjalan tetap dihitung per-HP.
Map<String, dynamic> accountToMap(
  Account a,
  String householdId,
  String uid, {
  DateTime? now,
}) {
  final t = now ?? syncNow();
  return {
    'uuid': a.uuid ?? '',
    'name': a.name,
    'isArchived': a.isArchived,
    'sortOrder': a.sortOrder,
    'openingBalance': a.openingBalance,
    // v1.32: toggle keluarga ikut push (LWW di HP lain via upsert).
    'isShared': a.isShared,
    'updatedAt': (a.updatedAt ?? t).millisecondsSinceEpoch,
    if (a.deletedAt != null) 'deletedAt': a.deletedAt!.millisecondsSinceEpoch,
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

/// null = dokumen sampah (tanpa uuid) → skip, bukan crash.
RemoteAccount? parseRemoteAccount(Map<String, dynamic> m) {
  final uuid = m['uuid'] as String?;
  if (uuid == null || uuid.isEmpty) return null;
  final now = syncNow();
  return (
    uuid: uuid,
    name: (m['name'] as String?) ?? '?',
    isArchived: (m['isArchived'] as bool?) ?? false,
    sortOrder: (m['sortOrder'] as int?) ?? 0,
    // v1.32: HP lama tanpa flag = pribadi (aman, bukan dishare diam2).
    isShared: (m['isShared'] as bool?) ?? false,
    // v1.36.2: dokumen lama tanpa openingBalance → null (jangan timpa
    // angka lokal dengan 0).
    openingBalance: (m['openingBalance'] as num?)?.toInt(),
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
    accountUuid: m['accountUuid'] as String?,
    transferId: m['transferId'] as String?,
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
  final local = await (db.select(
    db.categories,
  )..where((c) => c.uuid.equals(r.uuid))).getSingleOrNull();
  if (local == null) {
    await db
        .into(db.categories)
        .insert(
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

/// Upsert dompet per uuid (v1.25). Return true bila berubah.
/// Hanya identitas + arsip (saldo dihitung per-HP — tak pernah sync).
/// Konflik nama + uuid SAMA + beda nama = LWW menang (wajar: rename
/// terakhir yang dilihat semua HP).
Future<bool> upsertLocalAccount(
  AppDatabase db,
  RemoteAccount r,
  String householdId,
) async {
  final local = await (db.select(
    db.accounts,
  )..where((a) => a.uuid.equals(r.uuid))).getSingleOrNull();
  if (local == null) {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: r.name,
            isArchived: Value(r.isArchived),
            sortOrder: Value(r.sortOrder),
            isShared: Value(r.isShared),
            openingBalance: Value(r.openingBalance ?? 0),
            uuid: Value(r.uuid),
            updatedAt: Value(r.updatedAt),
            deletedAt: Value(r.deletedAt),
            householdId: Value(householdId),
          ),
        );
    return true;
  }
  if (!remoteWins(local.updatedAt, r.updatedAt)) return false;
  await (db.update(db.accounts)..where((a) => a.id.equals(local.id))).write(
    AccountsCompanion(
      name: Value(r.name),
      isArchived: Value(r.isArchived),
      sortOrder: Value(r.sortOrder),
      isShared: Value(r.isShared),
      openingBalance: r.openingBalance == null
          ? const Value.absent()
          : Value(r.openingBalance!),
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
///
/// v1.25: `accountUuid` remote → `accountId` lokal (cari uuid akun);
/// tidak ketemu = null (ikut gabungan, tak hilang). `transferId`
/// grup ditulis apa adanya (uuid global unik — sama di semua HP).
Future<bool> upsertLocalTx(
  AppDatabase db,
  RemoteTx r,
  String householdId,
) async {
  final local = await (db.select(
    db.transactions,
  )..where((t) => t.uuid.equals(r.uuid))).getSingleOrNull();
  final catId = await _localCategoryId(db, r.categoryUuid);
  final acctId = await _localAccountId(db, r.accountUuid);
  if (local == null) {
    await db
        .into(db.transactions)
        .insert(
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
            accountId: Value(acctId),
            accountUuid: Value(r.accountUuid),
            transferId: Value(r.transferId),
          ),
        );
    return true;
  }
  if (!remoteWins(local.updatedAt, r.updatedAt)) return false;
  await (db.update(db.transactions)..where((t) => t.id.equals(local.id))).write(
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
      accountId: Value(acctId),
      accountUuid: Value(r.accountUuid),
      transferId: Value(r.transferId),
    ),
  );
  return true;
}

Future<int?> _localCategoryId(AppDatabase db, String? uuid) async {
  if (uuid == null || uuid.isEmpty) return null;
  final cat = await (db.select(
    db.categories,
  )..where((c) => c.uuid.equals(uuid))).getSingleOrNull();
  return cat?.id;
}

/// v1.25: `accountUuid` remote → `accountId` lokal. Tidak ketemu = null
/// (ikut gabungan — transaksi tak hilang walau dompet belum sync).
Future<int?> _localAccountId(AppDatabase db, String? uuid) async {
  if (uuid == null || uuid.isEmpty) return null;
  final acc = await (db.select(
    db.accounts,
  )..where((a) => a.uuid.equals(uuid))).getSingleOrNull();
  return acc?.id;
}

// ---------- Seleksi push ----------

/// true bila transaksi cermin utang (debtId terisi) → JANGAN push mentah.
/// Cermin di-rebuild per-HP di Fase 3 dari debts yang di-sync.
bool isMirrorTx(Transaction t) => t.debtId != null;

/// Semua kategori lokal (hidup + tombstone) untuk push penuh beta.
Future<List<Category>> pushableCats(AppDatabase db) =>
    db.select(db.categories).get();

/// Transaksi yang boleh di-push: non-cermin DAN milik dompet bertanda
/// `isShared` (v1.36.2 — privacy). `accountUuid` null (baris lama) TIDAK
/// di-push: tanpa dompet keluarga, tidak ada alasan ikut ke cloud.
Future<List<Transaction>> pushableTx(AppDatabase db) async {
  final shared = await pushableAccounts(db);
  final sharedUuids = shared.map((a) => a.uuid).whereType<String>().toSet();
  final all = await db.select(db.transactions).get();
  return all
      .where(
        (t) =>
            !isMirrorTx(t) &&
            t.accountUuid != null &&
            sharedUuids.contains(t.accountUuid),
      )
      .toList();
}

/// Dompet yang boleh di-push: HANYA yang bertanda `isShared` (v1.36.2).
/// Dompet pribadi tidak pernah menyentuh cloud, jadi anggota rumah tidak
/// bisa melihat nama/saldonya. Kebijakan ini menggantikan "push semua".
Future<List<Account>> pushableAccounts(AppDatabase db) =>
    (db.select(db.accounts)..where((a) => a.isShared.equals(true))).get();

/// Layar kedua privacy (v1.36.2): dokumen dompet pribadi hanya diterima
/// bila baris lokalnya sudah ada (kasus toggle Keluarga → Pribadi pada
/// HP lain). HP yang belum pernah punya baris itu tidak akan dibuat.
Future<bool> shouldPullAccount(AppDatabase db, RemoteAccount r) async {
  if (r.isShared) return true;
  final local = await (db.select(
    db.accounts,
  )..where((a) => a.uuid.equals(r.uuid))).getSingleOrNull();
  return local != null;
}

/// Layar kedua privacy (v1.36.2): transaksi remote hanya di-pull bila
/// dompetnya benar-benar bertanda Keluarga di remote. Transaksi tanpa
/// `accountUuid` (data lama) ikut ditolak — bukan data keluarga baru.
bool pullableTx(RemoteTx r, Set<String> sharedAccountUuids) =>
    r.accountUuid != null && sharedAccountUuids.contains(r.accountUuid);

/// Stamp `householdId` + pastikan uuid/updatedAt dompet terisi (v1.25).
Future<void> stampPushedAccounts(
  AppDatabase db,
  Iterable<int> ids,
  String householdId,
) async {
  final now = syncNow();
  for (final id in ids) {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) continue;
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        householdId: Value(householdId),
        uuid: Value(row.uuid ?? newSyncUuid()),
        updatedAt: Value(row.updatedAt ?? now),
      ),
    );
  }
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
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
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
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
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
