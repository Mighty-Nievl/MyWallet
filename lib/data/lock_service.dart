import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// PIN disimpan sebagai hash di secure storage (bukan plaintext).
class LockService {
  static const _pinKey = 'app_pin_hash';
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  /// Hash sederhana (DJB2 + salt statis) — cukup untuk PIN lokal 6 digit.
  /// Bukan untuk keamanan server-grade; tujuannya menghalangi baca santai.
  static String hashPin(String pin) {
    var h1 = 5381;
    var h2 = 52711;
    final s = 'mw::$pin::salt';
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      h1 = ((h1 << 5) + h1 + c) & 0x7fffffff;
      h2 = ((h2 << 5) + h2 + c) & 0x7fffffff;
    }
    return '${h1.toRadixString(16)}${h2.toRadixString(16)}';
  }

  static Future<bool> hasPin() async =>
      (await _storage.read(key: _pinKey)) != null;

  static Future<void> setPin(String pin) async =>
      _storage.write(key: _pinKey, value: hashPin(pin));

  static Future<void> clearPin() async => _storage.delete(key: _pinKey);

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;
    return stored == hashPin(pin);
  }

  static Future<bool> canUseBiometric() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka MyWallet',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
