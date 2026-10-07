import 'package:flutter/material.dart';

import 'screens/budget_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/tx_form_screen.dart';
import 'design/app_colors.dart';
import 'design/app_radius.dart';
import 'design/app_spacing.dart';

/// Kerangka utama: 4 tab + tombol + di tengah.
/// [ home ] [ history ] [ + ] [ budget ] [ laporan ]
/// Pengaturan dibuka dari ikon kanan atas Beranda (bukan tab).
///
/// STEP 3 — navigasi custom MyWallet (bukan NavigationBar bawaan):
/// bar ramping + garis atas subtle, item aktif = pil permukaan aksen,
/// Catat = tombol aksen penuh di tengah. Destinasi & perilaku TETAP.
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
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(
              top: BorderSide(color: AppColors.borderOf(context)),
            ),
          ),
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
              // Catat: aksi utama — tombol aksen penuh di tengah.
              Expanded(
                child: InkWell(
                  onTap: _openAdd,
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    height: 56,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add,
                            size: 22,
                            color: scheme.onPrimary),
                        Text(
                          'Catat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
