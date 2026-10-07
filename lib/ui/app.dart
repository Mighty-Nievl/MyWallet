import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings.dart';
import 'app_theme.dart';
import 'screens/lock_screen.dart';
import 'shell.dart';

class MyWalletApp extends ConsumerWidget {
  const MyWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: child!,
          ),
          home: locked ? const LockScreen() : const AppShell(),
        );
      },
    );
  }
}
