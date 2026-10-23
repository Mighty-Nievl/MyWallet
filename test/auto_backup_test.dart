// v1.39.0 — backup harian: kapan BOLEH jalan + rotasi file.
//
// Yang diuji bukan penulisan SQLite (itu `backup_file_test.dart`), tapi
// kebijakan: dua kali backup dalam semenit dan nol backup sebulan
// sama-sama bug. Rotasi juga dikunci karena folder tak boleh tumbuh
// selamanya di HP 32 GB.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/auto_backup.dart';
import 'package:mywallet/data/backup_service.dart';
import 'package:mywallet/ui/format.dart';
import 'package:mywallet/ui/widgets/auto_backup_binder.dart';

Uint8List _dbBytes() => Uint8List.fromList(<int>[
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, // SQLite␣
      0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, // format␣
      0x33, 0x00,
      ...List<int>.filled(32, 0x41),
    ]);

_BackupHarness _harness() => _BackupHarness();

class _BackupHarness {
  int runCount = 0;
  bool enabled = true;
  bool throwOnRun = false;
  DateTime? last;
  DateTime now = DateTime(2026, 10, 23, 9);

  late final AutoBackupController c = AutoBackupController(
    run: () async {
      runCount++;
      if (throwOnRun) throw StateError('penyimpanan penuh');
      last = now;
    },
    isEnabled: () async => enabled,
    lastAt: () async => last,
    clock: () => now,
    minInterval: const Duration(hours: 20),
  );
}

/// Kirim event daur hidup lewat channel platform: `binding
/// .handleAppLifecycleStateChanged` itu `@protected`, memanggilnya dari
/// test = `invalid_use_of_protected_member` (analyze merah).
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState s) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(s.toString()),
    (_) {},
  );
  await tester.pump();
}

void main() {
  group('AutoBackupController', () {
    test('belum pernah backup: langsung jalan dan mencatat waktu', () async {
      final h = _harness();
      expect(await h.c.maybeRun('start'), isTrue);
      expect(h.runCount, 1);
      expect(h.c.runs, 1);
      expect(h.c.lastSuccess, h.now);
      expect(h.last, h.now);
    });

    test('dimatikan user: tidak menyentuh file sama sekali', () async {
      final h = _harness()..enabled = false;
      expect(await h.c.maybeRun('start'), isFalse);
      expect(h.runCount, 0);
      expect(h.c.skippedDisabled, 1);
      expect(h.c.runs, 0);
    });

    test('baru 3 jam lalu: ditahan (bukan backup tiap buka app)', () async {
      final h = _harness();
      h.last = h.now.subtract(const Duration(hours: 3));
      expect(await h.c.maybeRun('resume'), isFalse);
      expect(h.runCount, 0);
      expect(h.c.skippedFresh, 1);
    });

    test('lewat 21 jam: jalan lagi', () async {
      final h = _harness();
      h.last = h.now.subtract(const Duration(hours: 21));
      expect(await h.c.maybeRun('resume'), isTrue);
      expect(h.runCount, 1);
      expect(h.last, h.now); // waktu tercatat ulang
    });

    test('start lalu resume beruntun: hanya satu salinan', () async {
      final h = _harness();
      await h.c.maybeRun('start');
      await h.c.maybeRun('resume');
      expect(h.runCount, 1);
    });

    test('gagal menulis: tidak melempar, waktu TIDAK tercatat', () async {
      final h = _harness()..throwOnRun = true;
      expect(await h.c.maybeRun('start'), isFalse);
      expect(h.last, isNull);
      expect(h.c.failures, 1);
      expect(h.c.lastSuccess, isNull);
    });

    test('runNow melewati jatah 20 jam', () async {
      final h = _harness();
      h.last = h.now.subtract(const Duration(minutes: 5));
      expect(await h.c.runNow(), isTrue);
      expect(h.runCount, 1);
    });

    test('runNow tetap hormat switch mati', () async {
      final h = _harness()..enabled = false;
      expect(await h.c.runNow(), isFalse);
      expect(h.runCount, 0);
    });
  });

  group('rotasi file backup', () {
    test('nama file urut abjad = urut waktu', () {
      expect(
        BackupService.autoBackupName(DateTime(2026, 10, 23, 9, 5)),
        'mywallet-auto-20261023-0905.sqlite',
      );
    });

    test('writeAutoBackup menyimpan salinan + menyisakan 3 terbaru', () async {
      final dir = await Directory.systemTemp.createTemp('mw-autobak-');
      try {
        final src = File('${dir.path}/mywallet.sqlite');
        await src.writeAsBytes(_dbBytes());

        for (var i = 0; i < 5; i++) {
          await BackupService.writeAutoBackup(
            src,
            dir,
            keep: 3,
            now: DateTime(2026, 10, 23, 9, i),
          );
        }

        final files = await BackupService.listAutoBackups(dir);
        expect(files.length, 3);
        // Terbaru dulu, dan yang bertahan adalah tiga menit terakhir.
        expect(
          files.map((f) => f.uri.pathSegments.last).toList(),
          [
            'mywallet-auto-20261023-0904.sqlite',
            'mywallet-auto-20261023-0903.sqlite',
            'mywallet-auto-20261023-0902.sqlite',
          ],
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('listAutoBackups abaikan file lain di folder', () async {
      final dir = await Directory.systemTemp.createTemp('mw-autolist-');
      try {
        await File('${dir.path}/catatan.txt').writeAsString('bukan backup');
        await File('${dir.path}/mywallet-backup-20261023-0900.sqlite')
            .writeAsBytes(_dbBytes());
        final files = await BackupService.listAutoBackups(dir);
        expect(files, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('keep 0 diperlakukan 1 — folder tidak boleh kosong', () async {
      final dir = await Directory.systemTemp.createTemp('mw-autokeep-');
      try {
        final src = File('${dir.path}/mywallet.sqlite');
        await src.writeAsBytes(_dbBytes());
        for (var i = 0; i < 3; i++) {
          await BackupService.writeAutoBackup(
            src,
            dir,
            keep: 3,
            now: DateTime(2026, 10, 23, 9, i),
          );
        }
        final deleted = await BackupService.pruneAutoBackups(dir, keep: 0);
        expect(deleted, 2);
        expect((await BackupService.listAutoBackups(dir)).length, 1);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('label tampilan', () {
    final now = DateTime(2026, 10, 23, 12);

    test('backupAgeLabel', () {
      expect(backupAgeLabel(now, now: now), 'Baru saja');
      expect(
        backupAgeLabel(now.subtract(const Duration(minutes: 42)), now: now),
        '42 menit lalu',
      );
      expect(
        backupAgeLabel(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
      expect(
        backupAgeLabel(now.subtract(const Duration(days: 1)), now: now),
        'Kemarin',
      );
      expect(
        backupAgeLabel(now.subtract(const Duration(days: 9)), now: now),
        '9 hari lalu',
      );
      // Lebih dari 30 hari: tanggal absolut, bukan "97 hari lalu".
      expect(
        backupAgeLabel(now.subtract(const Duration(days: 40)), now: now),
        formatDate(now.subtract(const Duration(days: 40))),
      );
    });

    test('formatBytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(2621440), '2.5 MB');
    });
  });

  group('AutoBackupBinder', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AutoBackupBinder(
              trigger: (t) async => calls.add(t),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('menembak start sekali setelah frame pertama', (tester) async {
      expect(await pump(tester), ['start']);
    });

    testWidgets('menembak resume saat kembali dari background', (tester) async {
      final calls = await pump(tester);
      await _lifecycle(tester, AppLifecycleState.paused);
      await _lifecycle(tester, AppLifecycleState.resumed);
      expect(calls, contains('resume'));
    });
  });
}
