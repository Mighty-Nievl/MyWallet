import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_service.dart';
import 'database.dart';
import 'household.dart';
import 'sync_engine.dart';

/// Status sync beta (v1.19) — tampil di Keluarga → Sinkronisasi.
enum SyncPhase { idle, working, done, failed }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.message = '',
    this.pushed = 0,
    this.pulled = 0,
    this.at,
  });
  final SyncPhase phase;
  final String message;
  final int pushed;
  final int pulled;
  final DateTime? at;
}

/// Sync engine beta Fase 2: push/pull transaksi + kategori antar-HP
/// serumah. Opt-in — tanpa household = nol jalan.
/// v1.25: + dompet (identitas + arsip, tanpa saldo).
///
/// Kontrak (keputusan roadmap):
/// - Offline-first tetap: tiap tahap `.timeout()` + pesan ramah;
///   gagal = state failed, data lokal TIDAK tersentuh.
/// - Last-write-wins per baris via `updatedAt` ([remoteWins]).
/// - Cermin utang TIDAK di-push mentah ([isMirrorTx]) — rebuild per-HP
///   Fase 3. Pull men-skip dokumen cermin bila ada yang nyasar.
/// - Kaki transfer di-push sebagai 2 dokumen biasa + `transferId`
///   (netral di semua HP via filter `transfer_id IS NULL`).
/// - Urutan tahap: akun → transaksi (resolusi accountUuid satu siklus).
/// - Soft-delete merambat sebagai tombstone (`deletedAt`).
class SyncService {
  SyncService({FirebaseFirestore? store, AuthService? auth}) {
    try {
      _store = store ?? FirebaseFirestore.instance;
    } catch (_) {
      _store = null;
    }
    _auth = auth;
  }

  FirebaseFirestore? _store;
  AuthService? _auth;

  FirebaseFirestore _needStore() {
    final s = _store;
    if (s == null) {
      throw const FamilyException('Layanan sync belum siap di HP ini.');
    }
    return s;
  }

  static const opTimeout = Duration(seconds: 30);

  CollectionReference<Map<String, dynamic>> _catsOf(String hid) => _needStore()
      .collection(HouseholdPaths.households)
      .doc(hid)
      .collection('cats');

  CollectionReference<Map<String, dynamic>> _txOf(String hid) => _needStore()
      .collection(HouseholdPaths.households)
      .doc(hid)
      .collection('tx');

  /// Koleksi dompet (v1.25) — identitas + arsip, tanpa saldo.
  CollectionReference<Map<String, dynamic>> _accountsOf(String hid) =>
      _needStore()
          .collection(HouseholdPaths.households)
          .doc(hid)
          .collection('accounts');

  /// Satu siklus penuh: push lokal → pull remote → upsert LWW.
  /// [onProgress] opsional untuk update UI per tahap.
  Future<SyncState> syncNow(
    AppDatabase db, {
    void Function(String tahap)? onProgress,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return const SyncState(
        phase: SyncPhase.failed,
        message: 'Login dulu sebelum sync.',
      );
    }
    final s = await auth.currentCached();
    final hid = s.householdId;
    final u = s.uid;
    if (hid == null || hid.isEmpty || u == null) {
      return const SyncState(
        phase: SyncPhase.failed,
        message: 'Gabung/buat rumah tangga dulu sebelum sync.',
      );
    }
    try {
      var pushed = 0;
      var pulled = 0;

      // ---- PUSH kategori (penuh, beta) ----
      onProgress?.call('Mengirim kategori…');
      final cats = await pushableCats(db);
      final catIds = <int>[];
      for (final c in cats) {
        final uuid = c.uuid;
        if (uuid == null || uuid.isEmpty) continue;
        await _catsOf(hid)
            .doc(uuid)
            .set(catToMap(c, hid, u), SetOptions(merge: true))
            .timeout(opTimeout);
        pushed++;
        catIds.add(c.id);
      }
      await stampPushedCats(db, catIds, hid);

      // ---- PUSH dompet (v1.25, sebelum transaksi) ----
      // Urutan disengaja: HP lain yang pull di tengah siklus baca akun
      // dulu sebelum transaksi yang merujuknya.
      onProgress?.call('Mengirim dompet…');
      final accs = await pushableAccounts(db);
      final accIds = <int>[];
      for (final a in accs) {
        final uuid = a.uuid;
        if (uuid == null || uuid.isEmpty) continue;
        await _accountsOf(hid)
            .doc(uuid)
            .set(accountToMap(a, hid, u), SetOptions(merge: true))
            .timeout(opTimeout);
        pushed++;
        accIds.add(a.id);
      }
      await stampPushedAccounts(db, accIds, hid);

      // ---- PUSH transaksi non-cermin ----
      onProgress?.call('Mengirim transaksi…');
      final txs = await pushableTx(db);
      final txIds = <int>[];
      for (final t in txs) {
        final uuid = t.uuid;
        if (uuid == null || uuid.isEmpty) continue;
        await _txOf(hid)
            .doc(uuid)
            .set(txToMap(t, hid, u), SetOptions(merge: true))
            .timeout(opTimeout);
        pushed++;
        txIds.add(t.id);
      }
      await stampPushedTx(db, txIds, hid);

      // ---- PULL kategori ----
      onProgress?.call('Mengambil kategori…');
      final rCats = await _catsOf(hid)
          .get(const GetOptions(source: Source.server))
          .timeout(opTimeout);
      for (final d in rCats.docs) {
        final r = parseRemoteCat(d.data());
        if (r == null) continue;
        if (await upsertLocalCat(db, r, hid)) pulled++;
      }

      // ---- PULL dompet (v1.25, sebelum transaksi) ----
      // Urutan disengaja: upsertLocalTx butuh akun lokal untuk resolusi
      // accountUuid → accountId dalam SIKLUS YANG SAMA.
      // v1.36.2: privacy — dompet pribadi tidak dibuat di HP anggota.
      onProgress?.call('Mengambil dompet…');
      final rAccs = await _accountsOf(hid)
          .get(const GetOptions(source: Source.server))
          .timeout(opTimeout);
      final sharedAccUuids = <String>{};
      for (final d in rAccs.docs) {
        final r = parseRemoteAccount(d.data());
        if (r == null) continue;
        if (r.isShared && r.deletedAt == null) sharedAccUuids.add(r.uuid);
        if (!await shouldPullAccount(db, r)) continue;
        if (await upsertLocalAccount(db, r, hid)) pulled++;
      }

      // ---- PULL transaksi (skip cermin nyasar + dompet pribadi) ----
      onProgress?.call('Mengambil transaksi…');
      final rTxs = await _txOf(hid)
          .get(const GetOptions(source: Source.server))
          .timeout(opTimeout);
      for (final d in rTxs.docs) {
        final m = d.data();
        // Cermin tidak pernah di-push; bila ada (tulis manual console),
        // skip agar tidak ganda dengan rebuild Fase 3.
        if (m['debtId'] != null) continue;
        final r = parseRemoteTx(m);
        if (r == null) continue;
        // v1.36.2: hanya transaksi milik dompet yang dishare.
        if (!pullableTx(r, sharedAccUuids)) continue;
        if (await upsertLocalTx(db, r, hid)) pulled++;
      }

      return SyncState(
        phase: SyncPhase.done,
        message: 'Sync selesai.',
        pushed: pushed,
        pulled: pulled,
        at: DateTime.now(),
      );
    } catch (e) {
      return SyncState(phase: SyncPhase.failed, message: friendlyAuthError(e));
    }
  }
}

/// Provider service (AuthService di-inject dari provider sesi).
final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(auth: ref.watch(authServiceProvider));
  ref.onDispose(() {});
  return s;
});

/// Status terakhir (untuk UI Keluarga → Sinkronisasi).
final syncStateProvider = StateProvider<SyncState>((ref) => const SyncState());
