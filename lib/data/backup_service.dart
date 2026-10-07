import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'providers.dart';

/// Backup & restore file database SQLite + hapus semua data.
///
/// - Backup: baca byte file DB lalu tulis via `FilePicker.saveFile`
///   (API file_picker v13: `saveFile(fileName:, bytes:)` → `Uri?`).
///   CATATAN: ada jeda kecil antara baca byte & tulis; untuk pemakaian
///   pribadi (1 user, app idle saat backup) ini cukup konsisten.
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

  /// Backup DB ke file pilihan user. Return Uri hasil, null bila batal.
  static Future<Uri?> backupToFile(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final src = await _dbFile(db);
    final bytes = await src.readAsBytes();
    return FilePicker.saveFile(
      dialogTitle: 'Simpan backup MyWallet',
      fileName: defaultBackupName(),
      bytes: Uint8List.fromList(bytes),
    );
  }

  /// Pilih file backup (.sqlite/.db). Return path lokal, null bila batal.
  static Future<String?> pickRestoreFile() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file backup MyWallet',
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    if (files.isEmpty) return null;
    return files.single.path;
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
