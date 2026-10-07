import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// Backup & restore file database SQLite + hapus semua data.
///
/// - Backup: `VACUUM INTO` → konsisten walau DB sedang terbuka.
/// - Restore/hapus: DB harus ditutup dulu, lalu user restart aplikasi manual
///   (lihat dialog di layar Pengaturan).
class BackupService {
  static String defaultBackupName() {
    final now = DateTime.now();
    final t = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'mywallet-backup-$t.sqlite';
  }

  static Future<String?> pickSavePath(String fileName) =>
      FilePicker.saveFile(
        dialogTitle: 'Simpan backup MyWallet',
        fileName: fileName,
      );

  static Future<String?> pickRestoreFile() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file backup MyWallet',
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    return res?.files.single.path;
  }

  /// Backup konsisten via VACUUM INTO (path di-escape manual karena
  /// SQLite tidak menerima bound parameter untuk nama file).
  static Future<void> backupTo(WidgetRef ref, String destPath) async {
    final db = ref.read(dbProvider);
    final escaped = destPath.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped'");
  }

  /// Tutup koneksi DB aktif. Wajib sebelum restore/wipe.
  static Future<void> closeDatabase(WidgetRef ref) async {
    try {
      await ref.read(dbProvider).close();
    } catch (_) {
      // Abaikan: koneksi mungkin sudah tertutup.
    }
  }

  /// Timpa file DB aktif dengan file backup. Panggil setelah closeDatabase.
  /// Setelah ini aplikasi HARUS di-restart (tutup + buka lagi).
  static Future<void> restoreFrom(WidgetRef ref, String srcPath) async {
    final db = ref.read(dbProvider);
    final dest = await _dbFile(db);
    await File(srcPath).copy(dest.path);
    for (final suffix in ['-journal', '-wal', '-shm']) {
      final f = File('${dest.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  /// Hapus file DB aktif (reset total). Panggil setelah closeDatabase.
  /// Setelah ini aplikasi HARUS di-restart (DB + seed dibuat ulang).
  static Future<void> wipeAll(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final dest = await _dbFile(db);
    if (await dest.exists()) await dest.delete();
    for (final suffix in ['-journal', '-wal', '-shm']) {
      final f = File('${dest.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }
}

/// Lokasi file DB: dibaca lewat `PRAGMA database_list` agar tidak bergantung
/// pada API internal Drift.
Future<File> _dbFile(AppDatabase db) async {
  // Satu-satunya cara portabel: baca pragma database_list lewat koneksi.
  final rows = await db.customSelect('PRAGMA database_list').get();
  for (final r in rows) {
    if ((r.read<String>('name')) == 'main') {
      final file = r.read<String>('file');
      if (file.isNotEmpty) return File(file);
    }
  }
  throw StateError('Tidak bisa menemukan file database.');
}
