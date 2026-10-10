import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'household.dart';

/// Status sesi keluarga (opt-in — tanpa login = offline murni, nol berubah).
enum FamilyStatus {
  /// Belum dicek (booting).
  loading,

  /// Pribadi: belum login → app persis seperti sekarang.
  personal,

  /// Login tapi belum gabung/buat rumah tangga.
  signedIn,

  /// Anggota rumah tangga aktif (sync Fase 2 target hid ini).
  household,
}

/// Ringkasan sesi: siapa + rumah tangga mana (bila ada).
class FamilySession {
  const FamilySession({
    required this.status,
    this.uid,
    this.email,
    this.displayName,
    this.householdId,
    this.householdName,
  });

  final FamilyStatus status;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? householdId;
  final String? householdName;

  bool get isPersonal => status == FamilyStatus.personal;
}

/// Layanan login Google + rumah tangga (Fase 1, v1.17).
///
/// Kontrak offline-first:
/// - Semua method GAGAL-Aman: tanpa internet/config → [FamilyException]
///   pesan ramah, data lokal TIDAK tersentuh.
/// - [householdId] dicache di SharedPreferences (`household_id`) agar sesi
///   pulih offline saat boot (auth Firebase sendiri juga persist).
/// - Google Sign-In v7: `initialize` SEKALI → `attemptLightweight…`
///   (silent) → `authenticate()` (interaktif) → `idToken` →
///   `GoogleAuthProvider.credential`.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? store}) {
    // SENGAJA try/catch per-getter: di flutter test (tanpa
    // Firebase.initializeApp) `FirebaseAuth.instance` melempar
    // [core/no-app]. Konstruktor TIDAK boleh lempar agar provider tetap
    // bisa dibuat dan halaman Keluarga jatuh ke mode personal/offline.
    try {
      _auth = auth ?? FirebaseAuth.instance;
    } catch (_) {
      _auth = null;
    }
    try {
      _store = store ?? FirebaseFirestore.instance;
    } catch (_) {
      _store = null;
    }
  }

  FirebaseAuth? _auth;
  FirebaseFirestore? _store;

  /// Auth siap-pakai, atau [FamilyException] ramah bila Firebase belum
  /// init (test/offline-ekstrem). PemanggilUI menangkapnya jadi pesan
  /// inline — bukan crash.
  FirebaseAuth _needAuth() {
    final a = _auth;
    if (a == null) {
      throw const FamilyException('Layanan login belum siap di HP ini.');
    }
    return a;
  }

  /// Firestore siap-pakai, atau [FamilyException] ramah.
  FirebaseFirestore _needStore() {
    final s = _store;
    if (s == null) {
      throw const FamilyException('Layanan login belum siap di HP ini.');
    }
    return s;
  }
  bool _gsInit = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _gsSub;
  final _sessionCtrl = StreamController<FamilySession>.broadcast();

  static const householdIdKey = 'household_id';
  static const householdNameKey = 'household_name';

  /// Stream sesi (didorong tiap login/logout/gabung/keluar).
  Stream<FamilySession> get session => _sessionCtrl.stream;

  /// Boot: pulihkan sesi (silent login + cache lokal). Tidak lempar —
  /// semua kegagalan (Firebase belum init di test, offline, dsb) = personal.
  ///
  /// Anti-hang (insiden v1.17.2): `attemptLightweightAuthentication` di HP
  /// dengan CredentialManager nyangkut BISA tidak pernah selesai (future
  /// menggantung selamanya, bukan error). Karena itu dibungkus timeout
  /// 8 detik — lewat dari itu = personal, user tetap bisa tap login
  /// manual. Sama untuk `_sessionFor` (baca server).
  static const bootTimeout = Duration(seconds: 8);

  Future<FamilySession> boot() async {
    try {
      final u = await _currentUserSafe();
      if (u == null) {
        try {
          await _ensureGsInit();
          await GoogleSignIn.instance
              .attemptLightweightAuthentication()
              ?.timeout(bootTimeout);
        } catch (_) {
          // Silent gagal/timeout/mode-null: tetap personal.
        }
        final u2 = await _currentUserSafe();
        if (u2 == null) {
          return _emit(const FamilySession(status: FamilyStatus.personal));
        }
        try {
          return _emit(await _sessionFor(u2).timeout(bootTimeout));
        } catch (_) {
          return _emit(FamilySession(
            status: FamilyStatus.signedIn,
            uid: u2.uid,
            email: u2.email,
            displayName: u2.displayName,
          ));
        }
      }
      try {
        return _emit(await _sessionFor(u).timeout(bootTimeout));
      } catch (_) {
        return _emit(FamilySession(
          status: FamilyStatus.signedIn,
          uid: u.uid,
          email: u.email,
          displayName: u.displayName,
        ));
      }
    } catch (_) {
      return _emit(const FamilySession(status: FamilyStatus.personal));
    }
  }

  /// currentUser yang aman bila Firebase belum init (flutter test):
  /// null, bukan lempar.
  Future<User?> _currentUserSafe() async {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Login Google interaktif. Lempar [FamilyException] bila gagal.
  Future<FamilySession> signIn() async {
    try {
      await _ensureGsInit();
      final GoogleSignInAccount acct;
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        acct = await GoogleSignIn.instance.authenticate();
      } else {
        throw StateError('unsupported-platform');
      }
      final idToken = acct.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('empty-id-token');
      }
      final cred = await _needAuth().signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final u = cred.user ?? _auth?.currentUser;
      if (u == null) throw StateError('empty-firebase-user');
      await _ensureUserDoc(u);
      return _emit(await _sessionFor(u));
    } catch (e) {
      if (e is FamilyException) rethrow;
      throw FamilyException(friendlyAuthError(e));
    }
  }

  /// Logout: Firebase + Google + hapus cache rumah tangga lokal.
  /// Data transaksi lokal TIDAK dihapus (tetap milik HP ini).
  Future<FamilySession> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      // Lanjut: sesi lokal tetap dibersihkan.
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Abaikan.
    }
    await _clearHouseholdCache();
    return _emit(const FamilySession(status: FamilyStatus.personal));
  }

  /// Buat rumah tangga baru → jadi owner + kode invite 24 jam.
  Future<FamilySession> createHousehold(String name) async {
    final u = _auth?.currentUser;
    if (u == null) throw const FamilyException('Login dulu sebelum buat.');
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const FamilyException('Nama rumah tangga wajib diisi.');
    }
    try {
      final code = InviteCode.generate();
      final now = DateTime.now();
      final hid = _needStore().collection(HouseholdPaths.households).doc().id;
      final hRef = _needStore().collection(HouseholdPaths.households).doc(hid);
      final batch = _needStore().batch();
      batch.set(hRef, {
        'name': clean,
        'createdBy': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'inviteCode': code,
        'inviteExpiresAt':
            Timestamp.fromDate(now.add(HouseholdPaths.inviteTtl)),
      });
      batch.set(hRef.collection(HouseholdPaths.members).doc(u.uid), {
        'email': u.email,
        'displayName': u.displayName,
        'role': HouseholdPaths.roleOwner,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_needStore().collection(HouseholdPaths.invites).doc(code), {
        'householdId': hid,
        'createdBy': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(HouseholdPaths.inviteTtl)),
      });
      batch.set(_needStore().collection(HouseholdPaths.users).doc(u.uid), {
        'email': u.email,
        'displayName': u.displayName,
        'householdId': hid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      await _saveHouseholdCache(hid, clean);
      return _emit(await _sessionFor(u));
    } catch (e) {
      if (e is FamilyException) rethrow;
      throw FamilyException(friendlyAuthError(e));
    }
  }

  /// Gabung via kode invite (8 char). Validasi format lokal dulu.
  Future<FamilySession> joinHousehold(String rawCode) async {
    final u = _auth?.currentUser;
    if (u == null) throw const FamilyException('Login dulu sebelum gabung.');
    final code = InviteCode.parse(rawCode);
    if (!InviteCode.isValid(rawCode)) {
      throw FamilyException(friendlyJoinError(JoinFailure.badCode));
    }
    try {
      final invSnap =
          await _needStore().collection(HouseholdPaths.invites).doc(code).get();
      if (!invSnap.exists) {
        throw FamilyException(friendlyJoinError(JoinFailure.notFound));
      }
      final inv = invSnap.data()!;
      final hid = inv['householdId'] as String?;
      if (hid == null || hid.isEmpty) {
        throw FamilyException(friendlyJoinError(JoinFailure.notFound));
      }
      final exp = (inv['expiresAt'] as Timestamp?)?.toDate();
      if (exp == null || InviteCode.isExpired(exp, DateTime.now())) {
        throw FamilyException(friendlyJoinError(JoinFailure.expired));
      }
      final hSnap =
          await _needStore().collection(HouseholdPaths.households).doc(hid).get();
      final hName = (hSnap.data()?['name'] as String?) ?? 'Keluarga';
      final hRef = _needStore().collection(HouseholdPaths.households).doc(hid);
      final batch = _needStore().batch();
      batch.set(hRef.collection(HouseholdPaths.members).doc(u.uid), {
        'email': u.email,
        'displayName': u.displayName,
        'role': HouseholdPaths.roleMember,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_needStore().collection(HouseholdPaths.users).doc(u.uid), {
        'email': u.email,
        'displayName': u.displayName,
        'householdId': hid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      await _saveHouseholdCache(hid, hName);
      return _emit(await _sessionFor(u));
    } on FamilyException {
      rethrow;
    } catch (e) {
      throw FamilyException(friendlyAuthError(e));
    }
  }

  /// Ganti kode invite rumah tangga aktif (kode lama hangus).
  /// Hanya owner (dicek rules juga) — return kode BARU terformat.
  Future<String> rotateInviteCode() async {
    final s = await currentCached();
    final hid = s.householdId;
    final u = _auth?.currentUser;
    if (u == null || hid == null) {
      throw const FamilyException('Bukan anggota rumah tangga.');
    }
    try {
      final code = InviteCode.generate();
      final now = DateTime.now();
      final batch = _needStore().batch();
      batch.update(
          _needStore().collection(HouseholdPaths.households).doc(hid),
          {
            'inviteCode': code,
            'inviteExpiresAt':
                Timestamp.fromDate(now.add(HouseholdPaths.inviteTtl)),
          });
      batch.set(_needStore().collection(HouseholdPaths.invites).doc(code), {
        'householdId': hid,
        'createdBy': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(HouseholdPaths.inviteTtl)),
      });
      await batch.commit();
      return InviteCode.format(code);
    } catch (e) {
      if (e is FamilyException) rethrow;
      throw FamilyException(friendlyAuthError(e));
    }
  }

  /// Kode invite aktif rumah tangga (untuk ditampilkan + disalin).
  /// Return null bila tidak ada / kedaluwarsa (minta putar kode baru).
  Future<String?> activeInviteCode() async {
    final s = await currentCached();
    final hid = s.householdId;
    if (hid == null) return null;
    try {
      final snap = await _needStore()
          .collection(HouseholdPaths.households)
          .doc(hid)
          .get(GetOptions(source: Source.serverAndCache));
      final code = snap.data()?['inviteCode'] as String?;
      final exp =
          (snap.data()?['inviteExpiresAt'] as Timestamp?)?.toDate();
      if (code == null || exp == null) return null;
      if (InviteCode.isExpired(exp, DateTime.now())) return null;
      return InviteCode.format(code);
    } catch (_) {
      return null;
    }
  }

  /// Keluar dari rumah tangga (data lokal tetap, sync Fase 2 berhenti).
  Future<FamilySession> leaveHousehold() async {
    final u = _auth?.currentUser;
    final s = await currentCached();
    final hid = s.householdId;
    if (u == null || hid == null) {
      await _clearHouseholdCache();
      return _emit(const FamilySession(
        status: FamilyStatus.signedIn,
        uid: null,
      ));
    }
    try {
      await _needStore()
          .collection(HouseholdPaths.households)
          .doc(hid)
          .collection(HouseholdPaths.members)
          .doc(u.uid)
          .delete();
      await _needStore().collection(HouseholdPaths.users).doc(u.uid).set(
        {'householdId': null, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Lanjut: cache lokal tetap dibersihkan.
    }
    await _clearHouseholdCache();
    return _emit(await _sessionFor(u));
  }

  /// Sesi dari cache lokal (offline-safe, untuk boot cepat).
  Future<FamilySession> currentCached() async {
    final u = _auth?.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hid = prefs.getString(householdIdKey);
    final hName = prefs.getString(householdNameKey);
    if (u == null) {
      return const FamilySession(status: FamilyStatus.personal);
    }
    if (hid == null || hid.isEmpty) {
      return FamilySession(
        status: FamilyStatus.signedIn,
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
      );
    }
    return FamilySession(
      status: FamilyStatus.household,
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      householdId: hid,
      householdName: hName,
    );
  }

  // ---------- internal ----------

  Future<void> _ensureGsInit() async {
    if (_gsInit) return;
    await GoogleSignIn.instance.initialize();
    _gsSub ??= GoogleSignIn.instance.authenticationEvents.listen(
      (ev) async {
        if (ev is GoogleSignInAuthenticationEventSignOut) {
          await _clearHouseholdCache();
          _emit(const FamilySession(status: FamilyStatus.personal));
        }
      },
      onError: (_) {},
    );
    _gsInit = true;
  }

  Future<FamilySession> _emit(FamilySession s) async {
    if (!_sessionCtrl.isClosed) _sessionCtrl.add(s);
    return s;
  }

  Future<void> _ensureUserDoc(User u) async {
    try {
      await _needStore().collection(HouseholdPaths.users).doc(u.uid).set({
        'email': u.email,
        'displayName': u.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline / rules: sesi tetap jalan lokal.
    }
  }

  /// Sesi penuh: cache householdId → verifikasi ke server bila online.
  Future<FamilySession> _sessionFor(User u) async {
    final cached = await currentCached();
    String? hid = cached.householdId;
    String? hName = cached.householdName;
    // Bila cache kosong, tanya server (users/{uid}) — gagal = tetap signedIn.
    if (hid == null) {
      try {
        final snap = await _needStore()
            .collection(HouseholdPaths.users)
            .doc(u.uid)
            .get(GetOptions(source: Source.server));
        hid = snap.data()?['householdId'] as String?;
        if (hid != null && hid.isNotEmpty) {
          try {
            final hSnap = await _needStore()
                .collection(HouseholdPaths.households)
                .doc(hid)
                .get(GetOptions(source: Source.server));
            hName = hSnap.data()?['name'] as String?;
          } catch (_) {
            // Nama gagal: pakai default.
          }
          await _saveHouseholdCache(hid, hName);
        }
      } catch (_) {
        // Offline: tetap signedIn.
      }
    }
    if (hid == null || hid.isEmpty) {
      return FamilySession(
        status: FamilyStatus.signedIn,
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
      );
    }
    return FamilySession(
      status: FamilyStatus.household,
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      householdId: hid,
      householdName: hName,
    );
  }

  Future<void> _saveHouseholdCache(String hid, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(householdIdKey, hid);
    if (name != null) await prefs.setString(householdNameKey, name);
  }

  Future<void> _clearHouseholdCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(householdIdKey);
      await prefs.remove(householdNameKey);
    } catch (_) {
      // Abaikan.
    }
  }

  void dispose() {
    _gsSub?.cancel();
    _sessionCtrl.close();
  }
}

/// Provider layanan (satu instance).
final authServiceProvider = Provider<AuthService>((ref) {
  final s = AuthService();
  ref.onDispose(s.dispose);
  return s;
});

/// Sesi keluarga reaktif: boot sekali → stream update.
/// Tanpa login / tanpa Firebase init (flutter test) = personal (offline).
final familySessionProvider = StreamProvider<FamilySession>((ref) async* {
  yield const FamilySession(status: FamilyStatus.loading);
  AuthService svc;
  try {
    svc = ref.watch(authServiceProvider);
  } catch (_) {
    // Firebase belum init (test/widget): offline murni.
    yield const FamilySession(status: FamilyStatus.personal);
    return;
  }
  yield await svc.boot();
  yield* svc.session;
});
