import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/backup_service.dart';

/// Helper file-op backup/restore — SEMUA murni file-op via temp dir
/// (tanpa path_provider/koneksi DB) sehingga stabil di CI.
Uint8List validSqliteBytes([int extra = 64]) => Uint8List.fromList(<int>[
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, // SQLite␣
      0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, // format␣
      0x33, 0x00, // 3\0
      ...List<int>.filled(extra, 0x41),
    ]);

void main() {
  group('isSqliteHeader (validasi magic header)', () {
    test('header SQLite asli → true', () {
      expect(BackupService.isSqliteHeader(validSqliteBytes()), isTrue);
    });

    test('file kependekan (<16 byte) → false', () {
      expect(BackupService.isSqliteHeader(Uint8List.fromList([1, 2, 3])),
          isFalse);
    });

    test('file sampah → false', () {
      expect(
          BackupService.isSqliteHeader(
              Uint8List.fromList(List<int>.filled(100, 0xFF))),
          isFalse);
    });

    test('satu byte beda → false', () {
      final b = validSqliteBytes();
      b[15] = 0x01; // \0 → \1
      expect(BackupService.isSqliteHeader(b), isFalse);
    });
  });

  group('journalFiles + cleanJournals', () {
    test('tiga suffix pendamping terdaftar', () {
      final names = BackupService.journalFiles(File('/x/mywallet.sqlite'))
          .map((f) => f.path)
          .toList();
      expect(names, [
        '/x/mywallet.sqlite-journal',
        '/x/mywallet.sqlite-wal',
        '/x/mywallet.sqlite-shm',
      ]);
    });

    test('cleanJournals hapus yang ada, abaikan yang tidak ada', () async {
      final dir = await Directory.systemTemp.createTemp('mw-journal-');
      try {
        final db = File('${dir.path}/mywallet.sqlite');
        await db.writeAsBytes(validSqliteBytes());
        await File('${db.path}-wal').writeAsString('wal');
        await File('${db.path}-shm').writeAsString('shm');
        // -journal sengaja tidak dibuat.

        await BackupService.cleanJournals(db);

        expect(await db.exists(), isTrue); // DB utama utuh
        expect(await File('${db.path}-wal').exists(), isFalse);
        expect(await File('${db.path}-shm').exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('copyBackupTo (timpa + validasi)', () {
    test('file valid → dest tertimpa + jurnal bersih', () async {
      final dir = await Directory.systemTemp.createTemp('mw-copy-');
      try {
        final src = File('${dir.path}/backup.sqlite');
        await src.writeAsBytes(validSqliteBytes(128));
        final dest = File('${dir.path}/mywallet.sqlite');
        await dest.writeAsString('lama');
        await File('${dest.path}-wal').writeAsString('wal basi');

        await BackupService.copyBackupTo(src, dest);

        expect(await dest.readAsBytes(), validSqliteBytes(128));
        expect(await File('${dest.path}-wal').exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('file sampah → StateError + dest utuh', () async {
      final dir = await Directory.systemTemp.createTemp('mw-copy-bad-');
      try {
        final src = File('${dir.path}/palsu.sqlite');
        await src.writeAsString('bukan database');
        final dest = File('${dir.path}/mywallet.sqlite');
        await dest.writeAsString('data asli');

        expect(
          () => BackupService.copyBackupTo(src, dest),
          throwsA(isA<StateError>()),
        );
        expect(await dest.readAsString(), 'data asli');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('sumber hilang → StateError', () async {
      final dir = await Directory.systemTemp.createTemp('mw-copy-miss-');
      try {
        expect(
          () => BackupService.copyBackupTo(
            File('${dir.path}/tidak-ada.sqlite'),
            File('${dir.path}/mywallet.sqlite'),
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
