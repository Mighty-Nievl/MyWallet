import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci SharedPreferences untuk seluruh pengaturan.
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const hideBalance = 'hide_balance'; // bool
  static const startingBalance = 'starting_balance'; // int rupiah
  static const appLock = 'app_lock'; // 'none' | 'pin' | 'biometric'
  static const reminderEnabled = 'reminder_enabled'; // bool
  static const reminderHour = 'reminder_hour'; // int 0-23
  static const reminderMinute = 'reminder_minute'; // int 0-59
  // --- Tampilan (v1.2.0) ---
  static const accentColor = 'accent_color'; // nama warna, lihat AccentOptions
  static const useDynamicColor = 'use_dynamic_color'; // bool (Material You)
  static const trueBlack = 'true_black'; // bool (hitam pekat mode gelap)
  static const privacyScope = 'privacy_scope'; // 'balance' | 'all'
  static const showTopCategories = 'show_top_categories'; // bool
  static const showMonthTotals = 'show_month_totals'; // bool
  static const showDailyTotals = 'show_daily_totals'; // bool (ringkasan hari ini)
  static const showRecent = 'show_recent'; // bool
  static const recentCount = 'recent_count'; // int (3/5/10)
  static const compactAmounts = 'compact_amounts'; // bool (Rp25 jt)
  // --- Tampilan overkill (v1.2.0) ---
  static const fontScale = 'font_scale'; // 'small'|'normal'|'large'|'xlarge'
  static const compactList = 'compact_list'; // bool (list rapat)
  static const relativeDates = 'relative_dates'; // bool (Hari ini/Kemarin)
  static const showCategoryIcons = 'show_category_icons'; // bool
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

  // --- Tampilan ---

  Future<void> setAccentColor(String v) async {
    (await _prefs).setString(SettingsKeys.accentColor, v);
    _ref.invalidate(accentColorProvider);
  }

  Future<void> setUseDynamicColor(bool v) async {
    (await _prefs).setBool(SettingsKeys.useDynamicColor, v);
    _ref.invalidate(useDynamicColorProvider);
  }

  Future<void> setTrueBlack(bool v) async {
    (await _prefs).setBool(SettingsKeys.trueBlack, v);
    _ref.invalidate(trueBlackProvider);
  }

  Future<void> setPrivacyScope(String v) async {
    (await _prefs).setString(SettingsKeys.privacyScope, v);
    _ref.invalidate(privacyScopeProvider);
  }

  Future<void> setShowTopCategories(bool v) async {
    (await _prefs).setBool(SettingsKeys.showTopCategories, v);
    _ref.invalidate(showTopCategoriesProvider);
  }

  Future<void> setShowMonthTotals(bool v) async {
    (await _prefs).setBool(SettingsKeys.showMonthTotals, v);
    _ref.invalidate(showMonthTotalsProvider);
  }

  Future<void> setShowDailyTotals(bool v) async {
    (await _prefs).setBool(SettingsKeys.showDailyTotals, v);
    _ref.invalidate(showDailyTotalsProvider);
  }

  Future<void> setShowRecent(bool v) async {
    (await _prefs).setBool(SettingsKeys.showRecent, v);
    _ref.invalidate(showRecentProvider);
  }

  Future<void> setRecentCount(int v) async {
    (await _prefs).setInt(SettingsKeys.recentCount, v);
    _ref.invalidate(recentCountProvider);
  }

  Future<void> setCompactAmounts(bool v) async {
    (await _prefs).setBool(SettingsKeys.compactAmounts, v);
    _ref.invalidate(compactAmountsProvider);
  }

  Future<void> setFontScale(String v) async {
    (await _prefs).setString(SettingsKeys.fontScale, v);
    _ref.invalidate(fontScaleProvider);
  }

  Future<void> setCompactList(bool v) async {
    (await _prefs).setBool(SettingsKeys.compactList, v);
    _ref.invalidate(compactListProvider);
  }

  Future<void> setRelativeDates(bool v) async {
    (await _prefs).setBool(SettingsKeys.relativeDates, v);
    _ref.invalidate(relativeDatesProvider);
  }

  Future<void> setShowCategoryIcons(bool v) async {
    (await _prefs).setBool(SettingsKeys.showCategoryIcons, v);
    _ref.invalidate(showCategoryIconsProvider);
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

// ---------- Tampilan ----------

/// Nama warna aksen. Lihat AccentOptions di app_theme.dart.
final accentColorProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getString(SettingsKeys.accentColor) ?? 'green';
});

/// Ikuti warna wallpaper HP (Material You, Android 12+).
final useDynamicColorProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.useDynamicColor) ?? false;
});

/// Hitam pekat di mode gelap (hemat OLED).
final trueBlackProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.trueBlack) ?? false;
});

/// Cakupan privacy: 'balance' (hanya saldo) | 'all' (semua nominal).
final privacyScopeProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  final v = p.getString(SettingsKeys.privacyScope);
  return v == 'all' ? 'all' : 'balance';
});

/// Tampilkan seksi top kategori di Beranda.
final showTopCategoriesProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.showTopCategories) ?? true;
});

/// Tampilkan ringkasan masuk/keluar di kartu saldo.
final showMonthTotalsProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.showMonthTotals) ?? true;
});

/// Tampilkan ringkasan harian (hari ini) di Beranda.
final showDailyTotalsProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.showDailyTotals) ?? true;
});

/// Tampilkan seksi terakhir dicatat di Beranda.
final showRecentProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.showRecent) ?? true;
});

/// Jumlah transaksi di "terakhir dicatat".
final recentCountProvider = FutureProvider<int>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  final v = p.getInt(SettingsKeys.recentCount) ?? 5;
  return [3, 5, 10].contains(v) ? v : 5;
});

/// Nominal ringkas (Rp25 jt) vs penuh (Rp25.000.000).
final compactAmountsProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.compactAmounts) ?? false;
});

/// Skala font: 'small' | 'normal' | 'large' | 'xlarge'.
final fontScaleProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  final v = p.getString(SettingsKeys.fontScale);
  return ['small', 'normal', 'large', 'xlarge'].contains(v) ? v! : 'normal';
});

/// Nilai skala font sebagai faktor.
double fontScaleValue(String name) => switch (name) {
      'small' => 0.85,
      'large' => 1.15,
      'xlarge' => 1.3,
      _ => 1.0,
    };

/// Label Indonesia untuk skala font.
String fontScaleLabel(String name) => switch (name) {
      'small' => 'Kecil',
      'large' => 'Besar',
      'xlarge' => 'Sangat besar',
      _ => 'Normal',
    };

/// List rapat (kepadatan compact).
final compactListProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.compactList) ?? false;
});

/// Tanggal relatif ("Hari ini", "Kemarin") di list transaksi.
final relativeDatesProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.relativeDates) ?? true;
});

/// Tampilkan ikon emoji kategori di list.
final showCategoryIconsProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(prefsProvider.future);
  return p.getBool(SettingsKeys.showCategoryIcons) ?? true;
});

/// true bila SEMUA nominal harus disembunyikan (hide aktif + scope 'all').
bool hideAllAmounts(bool hide, String scope) => hide && scope == 'all';
