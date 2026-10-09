import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/budget_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tx_form_screen.dart';

/// Kerangka utama Material 3: 5 tab via [NavigationBar] +
/// FAB Catat mengambang (tanpa notch, tanpa spacer manual).
/// [ home ] [ history ] [ + ] [ budget ] [ laporan ] [ utang ]
/// Pengaturan dibuka dari header Beranda (bukan tab).
///
/// FAB dibuka via Container Transform ([OpenContainer]): tombol melebar
/// mulus menjadi halaman "Catat Transaksi". `tappable: false` agar yang
/// membuka hanya onPressed FAB (haptic dulu, baru transisi) — tanpa ini
/// tap bisa membuka dua kali. Tab aktif = indikator M3 bawaan.
/// Destinasi & perilaku TETAP.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 0=Beranda, 1=Riwayat, 2=Budget, 3=Laporan, 4=Utang
  int _index = 0;

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screens = [
      HomeScreen(onGoTab: _go),
      const HistoryScreen(),
      const BudgetScreen(),
      const ReportsScreen(),
      const DebtScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      // FAB aksen mengambang — Container Transform ke form Catat.
      floatingActionButton: OpenContainer(
        transitionType: ContainerTransitionType.fade,
        transitionDuration: const Duration(milliseconds: 450),
        openBuilder: (context, _) => const TxFormScreen(),
        closedElevation: 6,
        closedColor: scheme.primary,
        closedShape: const CircleBorder(),
        tappable: false,
        closedBuilder: (context, openContainer) => FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            openContainer();
          },
          tooltip: 'Catat transaksi',
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Utang',
          ),
        ],
      ),
    );
  }
}
