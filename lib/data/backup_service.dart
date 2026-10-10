import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'providers.dart';

/// Backup & restore file database SQLite + hapus semua data.
///
/// Lokasi file DB dihitung LANGSUNG (`getApplicationDocumentsDirectory()` +
/// `mywallet.sqlite` — sama persis dengan `_openConnection()` di
/// `database.dart`), SENGAJA tidak via `PRAGMA database_list`. Alasannya:
/// restore/wipe wajib menutup koneksi dulu, dan query apa pun lewat koneksi
/// yang sudah ditutup melempar
/// `Bad state ... PRAGMA database_list ... connection was closed`
/// (bug yang dilaporkan v1.16.0/1.16.1 — urutan close-dulu-PRAGMA-kemudian).
///
/// - Backup: checkpoint WAL dulu (konsisten) lalu baca byte via
///   `FilePicker.saveFile` (API file_picker v13: `saveFile(fileName:,
///   bytes:)` → `Uri?`). Untuk pemakaian pribadi (1 user, app idle saat
///   backup) ini cukup konsisten.
/// - Restore/wipe: hitung path → tutup koneksi → timpa/hapus file → user
///   restart aplikasi manual (lihat dialog di layar Pengaturan). File
///   restore divalidasi header SQLite dulu agar file sampah tidak merusak DB.
/// - Skema: backup v1.16.0 ↔ restore v1.16.1+ kompatibel (sama-sama
///   `schemaVersion` 3) — migrasi pindah package aman.
class BackupService {
  static String defaultBackupName() {
    final now = DateTime.now();
    final t = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'mywallet-backup-$t.sqlite';
  }

  /// Lokasi file DB aktif — TANPA perlu koneksi database, jadi aman
  /// dipanggil sebelum maupun sesudah [closeDatabase].
  static Future<File> dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'mywallet.sqlite'));
  }

  /// Backup DB ke file pilihan user. Return Uri hasil, null bila batal.
  static Future<Uri?> backupToFile(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    // Konsisten: paksa WAL checkpoint sebelum baca byte (no-op bila mode
    // jurnal bukan WAL). Gagal = abaikan, backup tetap jalan.
    try {
      await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
    } catch (_) {
      // Abaikan: backup baca file apa adanya.
    }
    final src = await dbFile();
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

  /// Tutup koneksi DB aktif. Idempoten — gagal = dianggap sudah tertutup.
  static Future<void> closeDatabase(WidgetRef ref) async {
    try {
      await ref.read(dbProvider).close();
    } catch (_) {
      // Abaikan: koneksi mungkin sudah tertutup.
    }
  }

  /// Timpa file DB aktif dengan file backup. Menutup koneksi sendiri di
  /// dalam (urutan: path → close → copy) sehingga TIDAK ADA query lewat
  /// koneksi tertutup. Setelah ini aplikasi HARUS di-restart.
  static Future<void> restoreFrom(WidgetRef ref, String srcPath) async {
    final dest = await dbFile();
    await closeDatabase(ref);
    await copyBackupTo(File(srcPath), dest);
  }

  /// Hapus file DB aktif (reset total). Menutup koneksi sendiri di dalam.
  /// Setelah ini aplikasi HARUS di-restart (DB + seed dibuat ulang).
  static Future<void> wipeAll(WidgetRef ref) async {
    final dest = await dbFile();
    await closeDatabase(ref);
    if (await dest.exists()) await dest.delete();
    await cleanJournals(dest);
  }

  /// 16 byte magic header SQLite (`SQLite format 3\0`).
  /// Murni (tanpa I/O/path_provider) — unit-testable.
  static bool isSqliteHeader(Uint8List bytes) {
    const header = <int>[
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, // SQLite
      0x20, // spasi
      0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, // format
      0x20, // spasi
      0x33, 0x00, // 3\0
    ];
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  /// File-file jurnal pendamping DB. Murni — unit-testable.
  static List<File> journalFiles(File db) => <File>[
        for (final s in ['-journal', '-wal', '-shm']) File('${db.path}$s'),
      ];

  /// Hapus jurnal pendamping yang ada (abaikan yang tidak ada).
  static Future<void> cleanJournals(File db) async {
    for (final f in journalFiles(db)) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Validasi header SQLite + timpa [dest] + bersih jurnal.
  /// Murni file-op (tanpa koneksi/path_provider) — unit-testable.
  /// Lempar [StateError] bila sumber hilang atau bukan SQLite valid.
  static Future<void> copyBackupTo(File src, File dest) async {
    if (!await src.exists()) {
      throw StateError('File backup tidak ditemukan.');
    }
    final bytes = await src.readAsBytes();
    if (!isSqliteHeader(bytes)) {
      throw StateError('File bukan database SQLite yang valid.');
    }
    await src.copy(dest.path);
    await cleanJournals(dest);
  }
}
