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
    final themeMode = ref.watch(themeModeProvider).value;
    final appLock = ref.watch(appLockProvider).value;
    final unlocked = ref.watch(unlockedProvider);
    final locked = (appLock ?? 'none') != 'none' && !unlocked;
    return MaterialApp(
      title: 'MyWallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode ?? ThemeMode.system,
      home: locked ? const LockScreen() : const AppShell(),
    );
  }
}
