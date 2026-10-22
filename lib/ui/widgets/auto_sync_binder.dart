import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_sync.dart';
import '../../data/connectivity.dart';

/// Pengikat sync otomatis ke daur hidup aplikasi (v1.38.5).
///
/// Tiga pemicu, semuanya tanpa user menekan apa pun:
/// 1. `start` — sekali setelah frame pertama app;
/// 2. `resume` — app dibuka lagi dari background;
/// 3. `online` — sinyal kembali setelah sempat mati (transisi
///    `true → false` pada [isOfflineProvider]), supaya catatan yang
///    dibuat offline terkirim begitu HP kembali online.
///
/// Penjatahan dan syarat (offline, rumah tangga, interval) ada di
/// [AutoSyncController], bukan di sini — widget ini hanya menyalurkan
/// kejadian, dan bisa diuji dengan menyuntik [trigger].
class AutoSyncBinder extends ConsumerStatefulWidget {
  const AutoSyncBinder({super.key, required this.child, this.trigger});

  final Widget child;

  /// Injeksi untuk test: kalau null, memakai [autoSyncProvider].
  final Future<void> Function(String trigger)? trigger;

  @override
  ConsumerState<AutoSyncBinder> createState() => _AutoSyncBinderState();
}

class _AutoSyncBinderState extends ConsumerState<AutoSyncBinder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fire('start'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fire('resume');
  }

  Future<void> _fire(String trigger) async {
    final injected = widget.trigger;
    if (injected != null) {
      await injected(trigger);
      return;
    }
    await ref.read(autoSyncProvider).maybeSync(trigger);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isOfflineProvider, (prev, next) {
      final wasOffline = prev?.value ?? false;
      final isOffline = next.value ?? false;
      if (wasOffline && !isOffline) _fire('online');
    });
    return widget.child;
  }
}
