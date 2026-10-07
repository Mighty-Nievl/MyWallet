import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/app.dart';
import 'data/reminder_service.dart';
import 'data/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pulihkan jadwal pengingat tiap aplikasi dibuka (jadwal sistem hilang saat HP restart).
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(SettingsKeys.reminderEnabled) ?? false) {
      final hour = prefs.getInt(SettingsKeys.reminderHour) ?? 20;
      final minute = prefs.getInt(SettingsKeys.reminderMinute) ?? 0;
      await ReminderService.scheduleDaily(hour, minute);
    }
  } catch (_) {
    // Gagal menjadwalkan = pengingat sekadar tidak bunyi; aplikasi tetap jalan.
  }
  runApp(const ProviderScope(child: MyWalletApp()));
}
