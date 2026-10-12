// Regresi v1.27 pohon akun: header Beranda kondisional login + halaman
// Profil + Keluarga keluar dari Pengaturan.
//
// Tanpa Firebase init (flutter test) — familySessionProvider jatuh ke
// personal/offline: header = wordmark, Profil = mode pribadi.
//
// Anti-flaky: tanpa pumpAndSettle; poll manual + try/finally; font Segoe
// ikut pola home_design_test.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/data/auth_service.dart';
import 'package:mywallet/data/database.dart';
import 'package:mywallet/data/providers.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/screens/home_screen.dart';
import 'package:mywallet/ui/screens/profile_screen.dart';
import 'package:mywallet/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _win = 'C:\\Windows\\Fonts';

Future<void> _loadFonts() async {
  Future<void> load(String family, String file) async {
    final f = File(file);
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('Roboto', '$_win\\segoeui.ttf');
  await load('Roboto', '$_win\\segoeuib.ttf');
  await load(
    'MaterialIcons',
    'E:\\dev\\flutter\\bin\\cache\\artifacts\\material_fonts'
        '\\materialicons-regular.otf',
  );
}

Future<AppDatabase> _newDb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final db = (await tester.runAsync(() async {
    final d = AppDatabase(NativeDatabase.memory());
    await d.backfillAccounts();
    return d;
  }))!;
  addTearDown(db.close);
  return db;
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int ticks = 60,
}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Lepas tree, lalu flush timer 0ms dari drift
/// (StreamQueryStore.markAsClosed) — tanpa ini binding test gagal di
/// invariant "A Timer is still pending". Bukan bug aplikasi.
/// Pola verbatim dari home_design_test.dart.
Future<void> _flushDriftCloseTimer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  // 1. Personal (belum login): wordmark + tombol Masuk → Profil + gear.
  // v1.27.1: tombol Masuk menutup lubang discoverability (Profil/Family
  // cuma reachable dari identitas login → logged-out terkunci total).
  testWidgets('v1.27 header personal: wordmark + Masuk → Profil + gear',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(onGoTab: (_) {}),
        ),
      ),
    );

    expect(await _waitFor(tester, find.text('MyWallet')), isTrue,
        reason: 'header personal harus wordmark MyWallet');
    expect(find.byTooltip('Pengaturan'), findsOneWidget);
    // Sapaan TIDAK tampil saat personal (nol berubah dari v1.26).
    expect(find.textContaining('Selamat'), findsNothing);
    // Tombol Masuk ada + tap → halaman Profil personal.
    expect(find.widgetWithText(TextButton, 'Masuk'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Masuk'));
    await tester.pump();
    expect(await _waitFor(tester, find.text('Profil')), isTrue,
        reason: 'tap Masuk harus buka halaman Profil');
    // Profil personal: hero + tombol Google besar (jalan login).
    expect(find.text('Masuk dengan Google'), findsWidgets);

    await _flushDriftCloseTimer(tester);
  });

  // 2. Login (override session): header = avatar + sapaan + nama; tap → Profil.
  testWidgets('v1.27 header login: avatar + sapaan → halaman Profil',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);
    const session = FamilySession(
      status: FamilyStatus.signedIn,
      email: 'rezalhbramantara@gmail.com',
      displayName: 'ReWin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          familySessionProvider.overrideWith(
            (ref) => Stream.value(session),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(onGoTab: (_) {}),
        ),
      ),
    );

    expect(await _waitFor(tester, find.text('ReWin')), isTrue,
        reason: 'header login harus tampilkan nama sapaan');
    // Wordmark digantikan identitas — bukan dobel.
    expect(find.text('MyWallet'), findsNothing);
    // Gear tetap ada di kanan.
    expect(find.byTooltip('Pengaturan'), findsOneWidget);

    // Tap identitas → halaman Profil terbuka.
    await tester.tap(find.text('ReWin'));
    await tester.pump();
    expect(await _waitFor(tester, find.text('Profil')), isTrue,
        reason: 'tap identitas harus buka halaman Profil');
    // Profil tampilkan pintu Keluarga + nama panggilan + masuk/keluar.
    expect(find.text('Keluarga'), findsOneWidget);
    expect(find.text('Nama panggilan'), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // 3. Hub Pengaturan: Keluarga SUDAH tidak ada (absence-test).
  testWidgets('v1.27 hub Pengaturan tanpa Keluarga (absence-test)',
      (tester) async {
    final db = await _newDb(tester);
    await tester.runAsync(_loadFonts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(await _waitFor(tester, find.text('Pengaturan')), isTrue);
    expect(find.text('Keluarga'), findsNothing,
        reason: 'Keluarga keluar dari hub — pohon akun via Profil');
    expect(find.text('Catat bareng pasangan'), findsNothing);
    // 4 grup tersisa tetap ada.
    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Tentang'), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // 4. Profil personal: kartu identitas + nickname editable + pintu Keluarga.
  testWidgets('v1.27 Profil personal: identitas + nickname + pintu Keluarga',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_loadFonts);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(await _waitFor(tester, find.text('Profil')), isTrue);
    // Mode pribadi: tombol masuk + nickname.
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.text('Nama panggilan'), findsOneWidget);
    expect(find.text('Keluarga'), findsOneWidget);
    expect(find.text('Belum masuk — mode pribadi'), findsOneWidget);

    // Tap nickname → dialog Nama sapaan terbuka (editable).
    final nick = find.text('Nama panggilan');
    expect(nick, findsOneWidget);
    await tester.tap(nick);
    await tester.pump();
    expect(await _waitFor(tester, find.text('Nama sapaan')), isTrue,
        reason: 'tap nickname harus buka dialog edit nama sapaan');
    // Dialog punya field + tombol Simpan.
    expect(find.widgetWithText(FilledButton, 'Simpan'), findsOneWidget);

    await _flushDriftCloseTimer(tester);
  });

  // 5. Profil → Keluarga: pintu pohon akun terbuka.
  testWidgets('v1.27 Profil → Keluarga: pintu pohon akun', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_loadFonts);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(await _waitFor(tester, find.text('Keluarga')), isTrue);
    await tester.tap(find.text('Keluarga'));
    await tester.pump();
    // Halaman Keluarga mandiri terbuka (hero personal).
    expect(await _waitFor(tester, find.text('Catat bareng pasangan')), isTrue,
        reason: 'tap baris Keluarga harus buka halaman Keluarga mandiri');
    // Hero Keluarga punya CTA FilledButton (satu-satunya di tree);
    // teksnya juga hidup di baris Profil di bawah route → findsWidgets.
    expect(find.text('Masuk dengan Google'), findsWidgets);
    expect(
      find.widgetWithText(FilledButton, 'Masuk dengan Google'),
      findsOneWidget,
    );

    await _flushDriftCloseTimer(tester);
  });
}
