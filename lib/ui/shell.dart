import 'package:flutter/material.dart';

import 'screens/budget_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tx_form_screen.dart';

/// Kerangka utama: 4 tab + tombol + di tengah.
/// [ home ] [ history ] [ + ] [ budget ] [ laporan ]
/// Pengaturan dibuka dari ikon kanan atas Beranda (bukan tab).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 0=Beranda, 1=Riwayat, 2=Budget, 3=Laporan
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    BudgetScreen(),
    ReportsScreen(),
  ];

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TxFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Petakan index layar ke index nav (0,1,3,4 — 2 adalah tombol +).
    final navIndex = _index >= 2 ? _index + 1 : _index;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) {
          if (i == 2) {
            _openAdd();
            return;
          }
          setState(() => _index = i > 2 ? i - 1 : i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            label: 'Catat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Budget',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}
