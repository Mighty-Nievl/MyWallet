// Test v1.36.1 — kunci aplikasi harus aktif lagi setelah app ke background,
// dan route yang sedang terbuka tidak boleh menutupi layar kunci.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/data/settings.dart';
import 'package:mywallet/ui/app.dart';
import 'package:mywallet/ui/screens/lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('background → terkunci lagi, route lama tetap utuh', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SettingsKeys.appLock: 'pin'});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.backfillAccounts());

    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        appLockProvider.overrideWith((ref) async => 'pin'),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyWalletApp(),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Sesi ini lolos kunci.
    container.read(unlockedProvider.notifier).state = true;
    await tester.pump();
    expect(find.byType(LockScreen), findsNothing);

    // Buka route lain — meniru Riwayat/Pengaturan yang sedang terbuka.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('halaman rahasia')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('halaman rahasia'), findsOneWidget);

    // Ke background lalu kembali: kunci menutup route yang terbuka.
    // (Saat paused frame memang dimatikan, jadi rebuild baru terlihat
    // setelah resumed — perilaku nyata HP juga begitu.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('halaman rahasia'), findsOneWidget);

    // Unlock: route lama kembali (navigasi tidak hilang).
    container.read(unlockedProvider.notifier).state = true;
    await tester.pump();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('halaman rahasia'), findsOneWidget);

    // Lepas tree + flush timer 0ms drift sebelum DB ditutup.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
