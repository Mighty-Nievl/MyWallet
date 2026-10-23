import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_backup.dart';

/// Pengikat backup otomatis ke daur hidup aplikasi (v1.39.0).
///
/// Dua pemicu, tanpa user menekan apa pun:
/// 1. `start` — sekali setelah frame pertama app;
/// 2. `resume` — app dibuka lagi dari background (kasus paling sering:
///    user mencatat transaksi pagi, menutup app, buka lagi malam).
///
/// Penjatahan (maksimal sekali per 20 jam) dan syarat (switch
/// "Backup otomatis") ada di [AutoBackupController], bukan di sini.
/// Widget ini hanya menyalurkan kejadian dan bisa diuji dengan menyuntik
/// [trigger] — pola yang sama dengan `AutoSyncBinder`.
class AutoBackupBinder extends ConsumerStatefulWidget {
  const AutoBackupBinder({super.key, required this.child, this.trigger});

  final Widget child;

  /// Injeksi untuk test: kalau null, memakai [autoBackupProvider].
  final Future<void> Function(String trigger)? trigger;

  @override
  ConsumerState<AutoBackupBinder> createState() => _AutoBackupBinderState();
}

class _AutoBackupBinderState extends ConsumerState<AutoBackupBinder>
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
    await ref.read(autoBackupProvider).maybeRun(trigger);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
