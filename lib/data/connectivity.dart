import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status SINYAL reaktif untuk UI Keluarga (v1.18.1).
///
/// `true` = radio mati total (ConnectivityResult.none: mode pesawat /
/// WiFi+data mati semua). BUKAN "tidak ada internet": WiFi nyala tapi
/// uplink mati (kasus 0,76 KB/S) tetap lolos sebagai `false` di sini —
/// kebenaran internet diputus di service via timeout 20 dtk + pesan
/// ramah (lapis kedua). Jadi teks UI preemptif bicara "sinyal", bukan
/// "internet", agar jujur.
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
