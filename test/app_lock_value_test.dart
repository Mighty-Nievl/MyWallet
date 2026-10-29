// Nilai `app_lock` yang rusak — dulu bikin label UI "Mati" tapi gerbang
// aplikasi (`appLock != 'none'`) mengunci layar. Tanpa PIN tersimpan,
// `LockService.verifyPin` selalu false → aplikasi tak bisa dibuka.
//
// Kontrak sekarang: hanya 'none' | 'pin' | 'biometric' yang sah; selain itu
// dinormalisasi ke 'none' di BACA dan di TULIS.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mywallet/data/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test(
    'nilai rusak di prefs dibaca sebagai none (tidak mengunci app)',
    () async {
      SharedPreferences.setMockInitialValues({'app_lock': 'pin-code'});
      final c = container();
      expect(await c.read(appLockProvider.future), 'none');
    },
  );

  test('nilai sah dipertahankan apa adanya', () async {
    SharedPreferences.setMockInitialValues({'app_lock': 'biometric'});
    final c = container();
    expect(await c.read(appLockProvider.future), 'biometric');
  });

  test('setter menolak nilai tak dikenal — tersimpan sebagai none', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    await c.read(settingsServiceProvider).setAppLock('weird');

    final p = await SharedPreferences.getInstance();
    expect(p.getString(SettingsKeys.appLock), 'none');
    expect(await c.read(appLockProvider.future), 'none');
  });

  test('setter menerima mode sah', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    await c.read(settingsServiceProvider).setAppLock('pin');

    final p = await SharedPreferences.getInstance();
    expect(p.getString(SettingsKeys.appLock), 'pin');
    expect(await c.read(appLockProvider.future), 'pin');
  });

  test('normalizeAppLock: semua nilai di luar whitelist → none', () {
    for (final raw in [null, '', 'PIN', 'pin ', 'true', 'biometrik']) {
      expect(normalizeAppLock(raw), 'none', reason: 'raw=$raw');
    }
    for (final ok in kAppLockModes) {
      expect(normalizeAppLock(ok), ok);
    }
  });
}
