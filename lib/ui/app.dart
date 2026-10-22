import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings.dart';
import 'app_theme.dart';
import 'screens/lock_screen.dart';
import 'shell.dart';
import 'widgets/auto_sync_binder.dart';

class MyWalletApp extends ConsumerStatefulWidget {
  const MyWalletApp({super.key});

  @override
  ConsumerState<MyWalletApp> createState() => _MyWalletAppState();
}

class _MyWalletAppState extends ConsumerState<MyWalletApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// v1.36.1: kunci ulang saat aplikasi ditinggal ke background.
  ///
  /// Sebelumnya `unlockedProvider` hanya direset oleh proses mati, jadi
  /// resume dari background langsung memperlihatkan data walau kunci
  /// aktif. Lock setelah `paused` (bukan `inactive`) supaya dialog izin
  /// singkat tidak memicu kunci palsu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    final lock = ref.read(appLockProvider).value ?? 'none';
    if (lock == 'none') return;
    ref.read(unlockedProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final appLock = ref.watch(appLockProvider).value ?? 'none';
    final unlocked = ref.watch(unlockedProvider);
    final locked = appLock != 'none' && !unlocked;

    final accent = ref.watch(accentColorProvider).value ?? 'green';
    final useDynamic = ref.watch(useDynamicColorProvider).value ?? false;
    final trueBlack = ref.watch(trueBlackProvider).value ?? false;
    final compact = ref.watch(compactListProvider).value ?? false;
    final fontScale = ref.watch(fontScaleProvider).value ?? 'normal';

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ThemeData light;
        final ThemeData dark;
        if (useDynamic && lightDynamic != null && darkDynamic != null) {
          light = AppTheme.fromScheme(lightDynamic, compact: compact);
          dark = AppTheme.fromScheme(
            darkDynamic,
            trueBlack: trueBlack,
            compact: compact,
          );
        } else {
          final seed = AppTheme.seedFor(accent);
          light = AppTheme.light(seed: seed, compact: compact);
          dark = AppTheme.dark(
            seed: seed,
            trueBlack: trueBlack,
            compact: compact,
          );
        }
        return MaterialApp(
          title: 'MyWallet',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler:
                  TextScaler.linear(fontScaleValue(fontScale)),
            ),
            // v1.36.1: kunci = overlay DI ATAS navigator. Dulu `home`
            // diganti LockScreen, sehingga route yang sedang di-push
            // (Riwayat, Scan, Pengaturan) tetap menutupi layar kunci saat
            // app dibuka lagi dari background. Sekarang konten di bawah
            // tertutup penuh dan route tetap utuh setelah unlock.
            child: locked
                ? Stack(
                    children: [
                      ?child,
                      const Positioned.fill(child: LockScreen()),
                    ],
                  )
                : child!,
          ),
          // v1.38.5: sync latar (start/resume/online). Penjatahan ada di
          // AutoSyncController; tanpa binding ini sync hanya jalan kalau
          // user menekan tombol di layar Keluarga.
          home: const AutoSyncBinder(child: AppShell()),
        );
      },
    );
  }
}
