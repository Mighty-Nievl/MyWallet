import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci SharedPreferences untuk seluruh pengaturan P0.
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const hideBalance = 'hide_balance'; // bool
  static const startingBalance = 'starting_balance'; // int rupiah
  static const appLock = 'app_lock'; // 'none' | 'pin' | 'biometric'
  static const reminderEnabled = 'reminder_enabled'; // bool
  static const reminderHour = 'reminder_hour'; // int 0-23
  static const reminderMinute = 'reminder_minute'; // int 0-59
}

/// Satu-satunya prefs provider (dipakai settings + actions).
final prefsProvider =
    FutureProvider<SharedPreferences>((_) => SharedPreferences.getInstance());

/// Status kunci aplikasi: sesi ini sudah lolos autentikasi atau belum.
final unlockedProvider = StateProvider<bool>((ref) => false);

/// Util baca/tulis pengaturan + invalidate provider terkait.
class SettingsService {
  SettingsService(this._ref);
  final Ref _ref;

  Future<SharedPreferences> get _prefs =>
      _ref.read(prefsProvider.future);

  Future<void> setThemeMode(String v) async {
    (await _prefs).setString(SettingsKeys.themeMode, v);
    _ref.invalidate(themeModeProvider);
  }

  Future<void> setHideBalance(bool v) async {
    (await _prefs).setBool(SettingsKeys.hideBalance, v);
    _ref.invalidate(hideBalanceProvider);
  }

  Future<void> setStartingBalance(int v) async {
    (await _prefs).setInt(SettingsKeys.startingBalance, v);
    _ref.invalidate(startingBalanceProvider);
  }

  Future<void> setAppLock(String v) async {
    (await _prefs).setString(SettingsKeys.appLock, v);
    _ref.invalidate(appLockProvider);
  }

  Future<void> setReminder(bool enabled, int hour, int minute) async {
    final p = await _prefs;
    await p.setBool(SettingsKeys.reminderEnabled, enabled);
    await p.setInt(SettingsKeys.reminderHour, hour);
    await p.setInt(SettingsKeys.reminderMinute, minute);
    _ref.invalidate(reminderProvider);
  }
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService(ref));

/// Mode tema aktif.
final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return switch (p.getString(SettingsKeys.themeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

/// Sembunyikan nominal saldo (mode privacy).
final hideBalanceProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.hideBalance) ?? false;
});

/// Saldo awal (rupiah). Ditambahkan ke saldo hasil hitung transaksi.
final startingBalanceProvider = FutureProvider<int>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getInt(SettingsKeys.startingBalance) ?? 0;
});

/// Mode kunci aplikasi: 'none' | 'pin' | 'biometric'.
final appLockProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getString(SettingsKeys.appLock) ?? 'none';
});

/// Konfigurasi pengingat harian.
final reminderProvider =
    FutureProvider<({bool enabled, int hour, int minute})>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return (
    enabled: p.getBool(SettingsKeys.reminderEnabled) ?? false,
    hour: p.getInt(SettingsKeys.reminderHour) ?? 20,
    minute: p.getInt(SettingsKeys.reminderMinute) ?? 0,
  );
});
