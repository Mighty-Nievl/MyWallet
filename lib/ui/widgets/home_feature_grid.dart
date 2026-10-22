import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../screens/accounts_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/debt_screen.dart';
import '../screens/reports_screen.dart';

/// Menu ringkas Beranda (v1.37): 4 pintasan yang TIDAK ada di dock.
///
/// Catat, Scan, dan Riwayat sudah punya rumah permanen di kapsul bawah;
/// menduplikasinya di Beranda hanya menambah tinggi dan pintu masuk.
/// Yang tersisa di sini adalah tujuan yang tak punya slot dock:
/// Pindah dana, Budget, Laporan, Utang.
class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({super.key});

  void _transfer(BuildContext context) {
    HapticFeedback.lightImpact();
    TransferSheet.show(context);
  }

  void _go(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(label: 'Menu'),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _LinkTile(
                icon: Icons.swap_horiz,
                label: 'Pindah dana',
                onTap: () => _transfer(context),
              ),
            ),
            Expanded(
              child: _LinkTile(
                icon: Icons.savings_outlined,
                label: 'Anggaran',
                onTap: () => _go(context, const BudgetScreen()),
              ),
            ),
            Expanded(
              child: _LinkTile(
                icon: Icons.bar_chart_outlined,
                label: 'Laporan',
                onTap: () => _go(context, const ReportsScreen()),
              ),
            ),
            Expanded(
              child: _LinkTile(
                icon: Icons.handshake_outlined,
                label: 'Utang',
                onTap: () => _go(context, const DebtScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppType.labelMuted(context).copyWith(letterSpacing: 0.6),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Tombol pintas: ikon outline polos + label. Sentuh ≥48px.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                icon,
                size: 26,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
