// Lint meminta `this._run` sebagai initializing formal, tapi parameter
// bernama tidak boleh diawali garis bawah di Dart (`required this._run`
// = error) dan membuat tiga parameter fungsi jadi posisional akan
// menghilangkan nama di call site. Penugasan manual dibiarkan.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_service.dart';
import 'providers.dart';
import 'settings.dart';

/// Backup otomatis (v1.39.0).
///
/// Kenapa ada: satu-satunya salinan data user adalah tombol "Backup
/// database" di Pengaturan → Kelola. Tombol itu butuh dua keputusan
/// (buka layar, pilih folder), jadi realitanya jarang ditekan; kalau HP
/// hilang/rusak sebelum pernah ditekan, seluruh catatan hilang. Sync
/// Firestore bukan pengganti karena hanya dompet `isShared` yang dikirim.
///
/// Aturan (tiap aturan punya test di `test/auto_backup_test.dart`):
/// - **diam bila dimatikan** — switch "Backup otomatis" = hak user;
/// - **maksimal sekali per [minInterval]** — `start` + `resume` beruntun
///   (cold start memang memicu keduanya) tidak boleh menulis dua file;
/// - **satu percobaan pada satu waktu** — `_busy` mencegah dua salinan
///   paralel saat app dibuka-tutup cepat;
/// - **tidak pernah melempar** — jalan di latar tanpa ada yang menunggu;
///   gagal = penghitung `failures` naik dan dicoba lagi di resume
///   berikutnya, data lokal tidak disentuh sama sekali.
///
/// Kelas ini tanpa widget/`WidgetRef` (pelajaran dari `AutoSyncController`):
/// semua ketergantungan masuk lewat konstruktor sehingga bisa diuji tanpa
/// memompa layar.
class AutoBackupController {
  AutoBackupController({
    required Future<void> Function() run,
    required Future<bool> Function() isEnabled,
    required Future<DateTime?> Function() lastAt,
    DateTime Function()? clock,
    this.minInterval = const Duration(hours: 20),
  }) : _run = run,
       _isEnabled = isEnabled,
       _lastAt = lastAt,
       _now = clock ?? DateTime.now;

  final Future<void> Function() _run;
  final Future<bool> Function() _isEnabled;
  final Future<DateTime?> Function() _lastAt;
  final DateTime Function() _now;
  final Duration minInterval;

  /// Waktu backup terakhir yang BERHASIL di sesi ini (null = belum).
  DateTime? lastSuccess;

  /// Penghitung diagnosa — tanpa ini "backup tidak jalan" tidak bisa
  /// dibedakan antara dimatikan, masih jatah, atau gagal menulis.
  int runs = 0;
  int skippedDisabled = 0;
  int skippedFresh = 0;
  int failures = 0;

  bool _busy = false;

  /// [trigger]: `start` | `resume`. Hanya untuk diagnosa, bukan logika.
  Future<bool> maybeRun(String trigger) async {
    if (_busy) return false;
    _busy = true;
    try {
      if (!await _isEnabled()) {
        skippedDisabled++;
        return false;
      }
      final last = await _lastAt();
      if (last != null && _now().difference(last) < minInterval) {
        skippedFresh++;
        return false;
      }
      return await _attempt();
    } finally {
      _busy = false;
    }
  }

  /// Tombol "Sekarang" — abaikan jatah, tetap hormati switch dan `_busy`.
  Future<bool> runNow() async {
    if (_busy) return false;
    _busy = true;
    try {
      if (!await _isEnabled()) {
        skippedDisabled++;
        return false;
      }
      return await _attempt();
    } finally {
      _busy = false;
    }
  }

  Future<bool> _attempt() async {
    runs++;
    try {
      await _run();
      lastSuccess = _now();
      return true;
    } catch (_) {
      failures++;
      return false;
    }
  }
}

final autoBackupProvider = Provider<AutoBackupController>((ref) {
  return AutoBackupController(
    isEnabled: () async {
      final p = await ref.read(prefsProvider.future);
      // Default ON: fitur ini justru untuk user yang tidak pernah menekan
      // tombol backup. Mematikannya tetap satu ketukan di Pengaturan.
      return p.getBool(SettingsKeys.autoBackup) ?? true;
    },
    lastAt: () async {
      final p = await ref.read(prefsProvider.future);
      final ms = p.getInt(SettingsKeys.lastBackupAt);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    },
    run: () async {
      final db = ref.read(dbProvider);
      // Konsisten: checkpoint WAL dulu supaya byte yang disalin sudah
      // berisi transaksi terakhir (sama seperti backup manual).
      try {
        await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      } catch (_) {
        // Abaikan: mode jurnal bukan WAL atau koneksi sibuk.
      }
      final src = await BackupService.dbFile();
      if (!await src.exists()) {
        // Belum ada DB = belum ada data. Lempar supaya percobaan ini
        // dihitung gagal dan diulang di resume berikutnya (bukan
        // mencatat "sudah backup" untuk file yang tidak ada).
        throw StateError('Database belum dibuat.');
      }
      final dir = await BackupService.autoBackupDir();
      await BackupService.writeAutoBackup(src, dir);
      final p = await ref.read(prefsProvider.future);
      await p.setInt(
        SettingsKeys.lastBackupAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      ref.invalidate(lastBackupAtProvider);
    },
  );
});
