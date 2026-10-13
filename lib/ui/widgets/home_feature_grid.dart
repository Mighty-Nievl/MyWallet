import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../scan_flow.dart';
import '../screens/accounts_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/debt_screen.dart';
import '../screens/history_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/tx_form_screen.dart';

/// Grid menu fitur Beranda v1.26 (slot `home:features`): 4 kolom × 2 baris.
///
/// Baris 1 "Aksi cepat" (mengubah data sekali tap) vs baris 2 "Lihat" (cuma
/// pindah halaman). Pemisah tiga lapis agar tak salah tap: label grup kecil
/// di atas tiap baris + sekat hairline antar baris + beda gaya tombol
/// (aksi = ikon dalam lingkaran isi warna tegas; pintas = ikon outline
/// polos tenang).
///
/// Semua aksi ikut dompet aktif (form catat + transfer + hasil scan baca
/// `selectedAccountProvider` di titik simpannya masing-masing — grid cuma
/// membuka pintu, bukan meneruskan id).
class HomeFeatureGrid extends ConsumerWidget {
  const HomeFeatureGrid({super.key});

  void _catat(BuildContext context, bool isExpense) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TxFormScreen(startAsExpense: isExpense),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(label: 'Aksi cepat'),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.arrow_downward,
                label: 'Catat masuk',
                color: AppColors.incomeOf(context),
                onTap: () => _catat(context, false),
              ),
            ),
            Expanded(
              child: _ActionTile(
                icon: Icons.arrow_upward,
                label: 'Catat keluar',
                color: AppColors.expenseOf(context),
                onTap: () => _catat(context, true),
              ),
            ),
            Expanded(
              child: _ActionTile(
                icon: Icons.swap_horiz,
                label: 'Pindah dana',
                color: Theme.of(context).colorScheme.primary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  TransferSheet.show(context);
                },
              ),
            ),
            Expanded(
              child: _ActionTile(
                icon: Icons.document_scanner_outlined,
                label: 'Scan struk',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => runScanFlow(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Divider(height: 1, thickness: 0.5, color: AppColors.borderOf(context)),
        const SizedBox(height: AppSpacing.s12),
        _GroupLabel(label: 'Lihat'),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _LinkTile(
                icon: Icons.receipt_long_outlined,
                label: 'Riwayat',
                onTap: () => _go(context, const HistoryScreen()),
              ),
            ),
            Expanded(
              child: _LinkTile(
                icon: Icons.savings_outlined,
                label: 'Budget',
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

/// Tombol aksi: lingkaran isi warna + label 2 baris. Sentuh ≥48px.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: scheme.onPrimary, size: 24),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
