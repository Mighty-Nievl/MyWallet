import 'package:flutter/material.dart';

import 'screens/budget_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tx_form_screen.dart';
import 'design/app_colors.dart';
import 'design/app_radius.dart';
import 'design/app_spacing.dart';

/// Kerangka utama: 4 tab + FAB Catat TERTANAM di tengah.
/// [ home ] [ history ] [ (+) ] [ budget ] [ laporan ]
/// Pengaturan dibuka dari ikon kanan atas Beranda (bukan tab).
///
/// FAB menyatu dengan bar via [BottomAppBar] + [CircularNotchedRectangle]:
/// Scaffold memotong cekungan (notch) persis di bawah FAB sehingga tombol
/// terlihat bernaung di bar. Dua syarat agar notch rapat + tidak belang:
/// 1. `extendBody: true` — body turun sampai ujung layar sehingga yang
///    terlihat lewat cekungan adalah konten, bukan background Scaffold.
/// 2. JANGAN bungkus [BottomAppBar] dengan [SafeArea] dari luar —
///    BottomAppBar sudah punya SafeArea INTERNAL di dalam material-nya
///    (padding di dalam bar, background ikut warna bar).
///    SafeArea luar menggeser bar ke atas: area gesture jadi background
///    Scaffold (blok hitam belang) + posisi notch miss dari FAB.
/// Tab aktif = pil permukaan aksen. Destinasi & perilaku TETAP.
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // Body sampai ujung layar — yang nongol lewat notch adalah konten,
      // bukan background Scaffold (sumber blok hitam belang).
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      // FAB lingkaran aksen — bentuk bulat agar pas di cekungan notch.
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        tooltip: 'Catat transaksi',
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      // Langsung BottomAppBar TANPA SafeArea pembungkus — safe area
      // sudah diurus SafeArea internal BottomAppBar. Jangan bungkus
      // dari luar (bikin belang + notch miss).
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.surfaceOf(context),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s8,
          AppSpacing.s8,
          AppSpacing.s8,
          AppSpacing.s8,
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Beranda',
                active: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Riwayat',
                active: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
            ),
            // Ruang kosong selebar FAB + margin notch (56 + 2×8).
            // Tanpa ini tab Budget/Laporan ketindih cekungan.
            const SizedBox(width: 72),
            Expanded(
              child: _NavItem(
                icon: Icons.savings_outlined,
                activeIcon: Icons.savings,
                label: 'Budget',
                active: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart,
                label: 'Laporan',
                active: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu item nav: ikon + label kecil.
/// Aktif = pil permukaan aksen + ikon/label aksen.
/// Nonaktif = ikon/label muted, transparan.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 22,
              color: active
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
