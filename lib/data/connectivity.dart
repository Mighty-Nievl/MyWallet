import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status internet reaktif untuk UI Keluarga (v1.18).
///
/// `true` = offline (tidak ada radio / ConnectivityResult.none).
/// Dipakai untuk disable tombol Buat/Gabung/Salin preemptif — bukan
/// menggantikan timeout + pesan ramah di service (pertahanan berlapis).
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  List<ConnectivityResult> current;
  try {
    current = await c.checkConnectivity();
  } catch (_) {
    current = const [ConnectivityResult.none];
  }
  yield _isNone(current);
  try {
    await for (final ev in c.onConnectivityChanged) {
      yield _isNone(ev);
    }
  } catch (_) {
    // Stream gagal: pertahankan status terakhir.
  }
});

bool _isNone(List<ConnectivityResult> r) =>
    r.isEmpty || r.every((e) => e == ConnectivityResult.none);
