import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/ui/screens/changelog_screen.dart';

import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/changelog.dart';

/// Regresi kritik brutal Changelog (v1.16.x):
/// 1. Tiap entri wajib bertanggal + copy user berbahasa manusia
///    (bukan commit log developer).
/// 2. Copy user DILARANG memuat istilah internal (uuid, skema DB, plugin,
///    minSdk, nama paket/secret/CI, Fase tanpa penjelasan).
/// 3. Halaman Changelog: judul + 3 kartu terbaru + grup versi lama +
///    tombol salin per entri + penanda TERINSTALL (bukan TERBARU-bohong).
void main() {
  test('tiap entri bertanggal + copy user + tech terisi', () {
    for (final e in appChangelog) {
      expect(e.version, matches(RegExp(r'^v\d+\.\d+\.\d+$')),
          reason: 'versi ${e.version} format vX.Y.Z');
      expect(e.date.trim(), isNotEmpty, reason: '${e.version} tanpa tanggal');
      expect(e.user.trim().length, greaterThan(20),
          reason: '${e.version} copy user terlalu pendek');
      expect(e.tech.trim(), isNotEmpty,
          reason: '${e.version} detail teknis kosong');
    }
  });

  test('copy user bebas istilah internal', () {
    // Daftar istilah yang hanya dimengerti developer — bila muncul di
    // copy user, entri itu bocor jadi commit log (insiden v1.16.x).
    final banned = RegExp(
      r'uuid|skema DB|plugin|minSdk|google-services|firebase|cloud_firestore|'
      r'google_sign_in|backfill|soft-delete|'
      r'categoryUuid|householdId|updatedAt|deletedAt|DB v\d|migrasi v\d|'
      r'Fase \d|WAL checkpoint|header SQLite',
      caseSensitive: false,
    );
    for (final e in appChangelog) {
      expect(
        e.user,
        isNot(matches(banned)),
        reason: '${e.version} copy user bocor istilah internal: "${e.user}"',
      );
    }
  });

  test('urutan terbaru dulu + versi unik', () {
    final versions = appChangelog.map((e) => e.version).toList();
    expect(versions.toSet(), hasLength(versions.length));
    // Terbaru dulu: nomor versi menurun.
    List<int> parts(String v) =>
        v.substring(1).split('.').map(int.parse).toList();
    for (var i = 0; i + 1 < versions.length; i++) {
      final a = parts(versions[i]);
      final b = parts(versions[i + 1]);
      var cmp = 0;
      for (var k = 0; k < 3; k++) {
        cmp = a[k].compareTo(b[k]);
        if (cmp != 0) break;
      }
      expect(cmp, 1, reason: '${versions[i]} harus lebih baru dari ${versions[i + 1]}');
    }
  });

  testWidgets('halaman changelog: struktur + salin + tanpa badge bohong',
      (tester) async {
    // Viewport default (aman bila test overflow 300px jalan duluan —
    // insiden viewport bocor antar-test saat run bareng).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Mock PackageInfo: di test env tidak ada platform channel, tanpa ini
    // future menggantung → halaman stuck di skeleton → kartu tak ketemu.
    // Versi mock = versi pubspec saat ini (punya badge TERINSTALL).
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'MyWallet',
          'packageName': 'com.rezal.mywallet',
          'version': '1.20.0',
          'buildNumber': '37',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ChangelogScreen(),
      ),
    );
    // JANGAN pumpAndSettle: AppSkeleton shimmer (repeat selamanya) tampil
    // selagi future PackageInfo belum selesai → tidak pernah settle.
    // Pump terbatas seperti home_design_test.dart; tunggu KARTU PERTAMA
    // (v terbaru) — bukan grup "Versi lama" di bawah yang butuh scroll
    // dulu untuk ter-build (ListView malas). Ditemukan via debug test:
    // mock terpanggil + kartu tampil, tapi loop break menunggu grup bawah.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text(appChangelog.first.version).evaluate().isNotEmpty) {
        break;
      }
    }

    // Judul halaman (bukan echo ganda judul+subtitle sheet lama).
    expect(find.text('Changelog'), findsOneWidget);
    // Badge TERBARU-bohong (i==0) sudah mati — yang ada TERINSTALL.
    expect(find.text('TERBARU'), findsNothing);
    // Versi mock terinstall → penanda TERINSTALL tampil tepat sekali.
    // Ia hidup di caption Text.rich ("10 Okt 2026 · TERINSTALL") jadi
    // dicari via textContaining, bukan find.text biasa.
    expect(find.textContaining('TERINSTALL'), findsOneWidget);
    // 3 versi terakhir tampil penuh sebagai kartu. ListView MALAS:
    // item yang jauh ter-scroll dibuang lagi (cacheExtent) — jadi SCROLL
    // (iteratif, bukan scrollUntilVisible-sekali) + ASSERT PER KARTU.
    // scrollUntilVisible butuh target SUDAH di tree; kartu di luar viewport
    // belum di-build → StateError "No element" (insiden debug). Pola aman:
    // drag pelan sampai target muncul, maksimal 10 ayunan.
    Future<void> reveal(String text) async {
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 10; i++) {
        if (find.text(text).evaluate().isNotEmpty) return;
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Assert versi+tanggal+tombol salin PER KARTU langsung setelah reveal
    // (jangan reveal semua → assert semua: kartu yang sudah jauh dibuang
    // lagi oleh ListView). Assertion global yang butuh seluruh tree
    // (grup bawah, tech-collapsed) dilakukan di posisi scroll-nya sendiri.
    for (final e in appChangelog.take(ChangelogScreen.recentCount)) {
      await reveal(e.version);
      expect(find.text(e.version), findsWidgets,
          reason: '${e.version} harus tampil di 3 kartu terbaru');
      expect(find.text(e.date), findsWidgets);
      expect(find.byTooltip('Salin ${e.version}'), findsOneWidget,
          reason: 'tombol salin ${e.version} hilang');
      // Tech kartu ini harus collapsed (bukan tembok teks langsung).
      expect(find.text(e.tech), findsNothing,
          reason: 'tech ${e.version} harus collapsed');
    }
    // Grup collapsed untuk versi lama — reveal dengan drag mentok bawah
    // (judulnya dinamis "Versi lama (N)", cari via containing manual).
    for (var i = 0; i < 10; i++) {
      if (find.textContaining('Versi lama').evaluate().isNotEmpty) break;
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -500),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('Versi lama'), findsOneWidget);
    // Judul "Detail teknis" ada di tiap kartu terbaru (expansion tile).
    expect(find.text('Detail teknis'), findsWidgets);
  });

  testWidgets('tidak overflow di viewport sempit 300px', (tester) async {
    tester.view.physicalSize = const Size(300, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ChangelogScreen(),
      ),
    );
    // Pump terbatas (alasan sama: skeleton shimmer tak pernah settle).
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Gagal otomatis bila ada RenderFlex overflow.
    expect(find.text('Changelog'), findsOneWidget);
  });
}
