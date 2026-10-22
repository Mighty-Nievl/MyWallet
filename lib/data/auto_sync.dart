import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'connectivity.dart';
import 'providers.dart';
import 'sync_service.dart';

/// Sync otomatis (v1.38.5).
///
/// Kenapa ada: `syncNow()` dulu hanya dipanggil dari satu tombol di layar
/// Keluarga (`family_screen.dart:947`), jadi `sync_engine.dart` (512 baris)
/// + `sync_service.dart` (224 baris) bergantung pada user mengingat satu
/// tombol di satu layar. Kalau tidak ditekan, dua HP serumah menampilkan
/// angka berbeda dan tidak ada yang memberi tahu.
///
/// Kelas ini sengaja **tanpa widget dan tanpa `WidgetRef`**: semua
/// ketergantungan masuk lewat konstruktor, jadi perilakunya bisa diuji
/// tanpa memompa layar. Itu pelajaran dari `deleteTransaction` yang harus
/// ditiru SQL-nya di test karena signature-nya menuntut `WidgetRef`.
///
/// Aturan (tiap aturan punya test di `test/auto_sync_test.dart`):
/// - **diam saat offline** — radio mati = tidak ada yang bisa dikirim;
///   jangan buang baterai dan kuota untuk percobaan yang pasti gagal;
/// - **diam tanpa rumah tangga** — sync butuh `householdId`; tanpa itu
///   `syncNow` hanya akan mengembalikan "gabung rumah tangga dulu";
/// - **`start` sekali per sesi** — membuka app berkali-kali dalam sehari
///   tidak boleh berarti berkali-kali push penuh;
/// - **`resume`/`online` dijatah** [minInterval] — pindah app berkali-kali
///   dalam semenit bukan alasan untuk sync berkali-kali;
/// - **tidak pernah melempar** — ini jalan di belakang layar tanpa ada
///   yang menunggu; gagal = `SyncState(failed)` dan data lokal utuh.
class AutoSyncController {
  AutoSyncController({
    required Future<SyncState> Function() run,
    required Future<bool> Function() isOffline,
    required Future<bool> Function() isReady,
    DateTime Function()? clock,
    this.minInterval = const Duration(minutes: 2),
  }) : _run = run,
       _isOffline = isOffline,
       _isReady = isReady,
       _now = clock ?? DateTime.now;

  final Future<SyncState> Function() _run;
  final Future<bool> Function() _isOffline;
  final Future<bool> Function() _isReady;
  final DateTime Function() _now;
  final Duration minInterval;

  /// Hasil percobaan terakhir (null = belum pernah jalan).
  SyncState? lastResult;
  DateTime? lastAttempt;

  /// Penghitung untuk diagnosa — tanpa ini, "sync tidak jalan" tidak bisa
  /// dibedakan antara offline, belum login, atau dijatah.
  int runs = 0;
  int skippedOffline = 0;
  int skippedNotReady = 0;
  int throttled = 0;

  bool _startDone = false;

  /// [trigger]: `start` | `resume` | `online`. Hanya dipakai untuk
  /// diagnosa, bukan logika.
  Future<SyncState?> maybeSync(String trigger) async {
    if (trigger == 'start') {
      if (_startDone) return null;
      // Ditandai SEBELUM await supaya dua trigger beruntun (start +
      // resume saat app dibuka dari cold start) tidak sama-sama lolos.
      _startDone = true;
    } else {
      final last = lastAttempt;
      if (last != null && _now().difference(last) < minInterval) {
        throttled++;
        return null;
      }
    }

    if (!await _isReady()) {
      skippedNotReady++;
      return null;
    }
    if (await _isOffline()) {
      skippedOffline++;
      return null;
    }

    lastAttempt = _now();
    runs++;
    try {
      final st = await _run();
      lastResult = st;
      return st;
    } catch (e) {
      // syncNow sudah menangani errornya sendiri; ini jaring untuk hal
      // tak terduga (plugin hilang, Firebase belum init, dsb).
      final st = SyncState(phase: SyncPhase.failed, message: '$e');
      lastResult = st;
      return st;
    }
  }
}

final autoSyncProvider = Provider<AutoSyncController>((ref) {
  final auth = ref.watch(authServiceProvider);
  return AutoSyncController(
    run: () async {
      final st = await ref
          .read(syncServiceProvider)
          .syncNow(ref.read(dbProvider));
      // Layar Keluarga membaca state ini; sync latar harus terlihat di
      // sana, bukan cuma di log yang tidak ada.
      ref.read(syncStateProvider.notifier).state = st;
      return st;
    },
    // null = belum ada emisi pertama. Dianggap "belum offline" karena
    // syncNow punya timeout 30 dtk sendiri; menahan sync karena status
    // sinyal belum terbaca justru membuat sync tidak pernah jalan.
    isOffline: () async => ref.read(isOfflineProvider).value ?? false,
    isReady: () async {
      try {
        final s = await auth.currentCached();
        return s.uid != null && (s.householdId ?? '').isNotEmpty;
      } catch (_) {
        return false;
      }
    },
  );
});
