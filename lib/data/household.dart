import 'dart:math';

/// Logika KELUARGA murni (Fase 1, v1.17) — TANPA dependensi Firebase.
///
/// Semua yang butuh network/state (GoogleSignIn, Firestore) tinggal di
/// `auth_service.dart`. Yang di sini murni + unit-testable:
/// - [InviteCode]: generate/format/parse/validasi kode gabung.
/// - [HouseholdPaths]: nama koleksi/dokumen Firestore (satu sumber).
/// - [friendlyAuthError]: pesan Indonesia ramah untuk error login.
///
/// Model Firestore (lihat juga `firestore.rules` di root repo):
/// - `households/{hid}`: {name, createdBy, createdAt, inviteCode,
///   inviteExpiresAt} — dibaca HANYA oleh anggota (rules `isMember`).
/// - `households/{hid}/members/{uid}`: {email, displayName, role, joinedAt}.
/// - `invites/{CODE}`: {householdId, householdName, createdBy, createdAt,
///   expiresAt} —
///   kode = capability secret (kayak link join grup): semua user login bisa
///   `get` BILA tahu kodenya. Random 8 char + kedaluwarsa 24 jam.
/// - `users/{uid}`: {email, displayName, householdId?, updatedAt} — sumber
///   "user gabung rumah tangga mana" per-HP (dicache ke prefs lokal juga).
abstract final class HouseholdPaths {
  static const households = 'households';
  static const members = 'members';
  static const invites = 'invites';
  static const users = 'users';

  static const roleOwner = 'owner';
  static const roleMember = 'member';

  /// Kode invite berlaku 24 jam sejak dibuat.
  static const inviteTtl = Duration(hours: 24);
}

/// Kode gabung rumah tangga: 8 char unambiguous (tanpa I/O/0/1 yang
/// gampang ketuker), ditampilkan `XXXX-XXXX`, disimpan TANPA dash.
abstract final class InviteCode {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 8;

  static final RegExp validPattern = RegExp(
    '^[$_alphabet]{$length}\$',
  );

  /// Generate kode baru (Random.secure). [random] opsional untuk test seed.
  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(_alphabet.length))
        .map((i) => _alphabet[i])
        .join();
  }

  /// Tampil: `ABCDEFGH` → `ABCD-EFGH`.
  static String format(String code) {
    final c = parse(code);
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }

  /// Normalisasi input user: buang dash/spasi, uppercase.
  static String parse(String raw) =>
      raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  /// true bila [raw] (setelah parse) = 8 char alfabet valid.
  static bool isValid(String raw) => validPattern.hasMatch(parse(raw));

  /// true bila [expiresAt] sudah lewat dari [now].
  static bool isExpired(DateTime expiresAt, DateTime now) =>
      !expiresAt.isAfter(now);
}

/// Error ramah (Indonesia) untuk kegagalan login/keluarga.
///
/// Murni: petakan dari string pesan exception (bukan tipe Firebase) agar
/// unit-testable tanpa SDK + stabil antar versi plugin.
String friendlyAuthError(Object e) {
  final m = e.toString().toLowerCase();
  if (m.contains('canceled') ||
      m.contains('cancelled') ||
      m.contains('dismissed') ||
      m.contains('sign_in_canceled')) {
    return 'Login dibatalkan.';
  }
  if (m.contains('network') ||
      m.contains('socket') ||
      m.contains('timeout') ||
      m.contains('unreachable') ||
      m.contains('failed host lookup')) {
    return 'Tidak ada internet — coba lagi saat online. Data lokal tetap aman.';
  }
  if (m.contains('developer_error') ||
      m.contains('api_not_connected') ||
      m.contains('apiexception') ||
      m.contains('serverclientid') ||
      m.contains('server_client_id') ||
      m.contains('clientconfigurationerror') ||
      m.contains('providerconfigurationerror') ||
      m.contains('empty-id-token')) {
    return 'Konfigurasi Google di HP ini belum cocok (SHA-1 / OAuth). Hubungi Rezal.';
  }
  if (m.contains('operation-not-allowed') ||
      m.contains('provider-not-enabled')) {
    return 'Login Google belum diaktifkan di server. Hubungi Rezal.';
  }
  if (m.contains('user-disabled')) {
    return 'Akun Google ini dinonaktifkan. Coba akun lain.';
  }
  if (m.contains('permission-denied') || m.contains('permission_denied')) {
    return 'Izin server belum dibuka untuk akun ini. Hubungi Rezal.';
  }
  if (m.contains('supportsauthenticate') ||
      m.contains('unsupported') ||
      m.contains('desktop') ||
      m.contains('windows')) {
    return 'Login Google hanya bisa di HP Android.';
  }
  return 'Login gagal — coba lagi.';
}

/// Pesan error gabung rumah tangga (kode invite).
String friendlyJoinError(JoinFailure f) => switch (f) {
      JoinFailure.badCode =>
        'Kode tidak valid — cek 8 huruf/angka dari pengundang.',
      JoinFailure.notFound =>
        'Kode tidak dikenal — mungkin salah ketik atau sudah diganti.',
      JoinFailure.expired =>
        'Kode kedaluwarsa (24 jam) — minta kode baru ke pengundang.',
    };

/// Alasan gabung gagal (murni, testable).
enum JoinFailure { badCode, notFound, expired }

/// Exception layanan keluarga — [message] SUDAH ramah untuk snackbar.
class FamilyException implements Exception {
  const FamilyException(this.message);
  final String message;
  @override
  String toString() => message;
}
