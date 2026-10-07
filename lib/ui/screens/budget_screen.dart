import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../amount_input.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_icon.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';

/// Layar budget bulanan per kategori.
///
/// STEP 3 — hanya UI/presentasi yang diubah. Logika TETAP:
/// CRUD budget, perhitungan spent/persen/over/warning (80%),
/// month selection, provider, dialog, validasi, navigasi.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final budgets = ref.watch(budgetsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: AppHeader(title: 'Budget'),
            ),
            const SizedBox(height: AppSpacing.s8),
            AppMonthNav(
              month: month,
              onShift: (d) => ref
                  .read(selectedMonthProvider.notifier)
                  .state = shiftMonth(month, d),
            ),
            Expanded(
              child: budgets.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Gagal memuat: $e',
                        style: AppType.secondary(context))),
                data: (list) {
                  if (list.isEmpty) {
                    return AppEmptyState(
                      icon: '💰',
                      title: 'Belum ada budget',
                      subtitle:
                          'Belum ada budget bulan ini.\nTambahkan batas per kategori agar pengeluaran terkontrol.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            _showBudgetDialog(context, ref, month),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Budget'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppRadius.md),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      96,
                    ),
                    children: [
                      _OverviewCard(list: list),
                      const SizedBox(height: AppSpacing.sectionGap),
                      AppSection(
                        title: 'Batas per kategori',
                        child: Column(
                          children: [
                            for (final b in list)
                              _BudgetItem(
                                item: b,
                                onDelete: () => deleteBudget(
                                    ref, b.budget.id),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showBudgetDialog(
                              context, ref, month),
                          icon: const Icon(Icons.add),
                          label:
                              const Text('Tambah / Ubah Budget'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    AppColors.borderOf(context)),
                            minimumSize:
                                const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.md),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetDialog(
      BuildContext context, WidgetRef ref, String month) async {
    final cats = await ref.read(expenseCategoriesProvider.future);
    int? catId;
    final limitCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Budget kategori'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                initialValue: catId,
                decoration: const InputDecoration(
                    labelText: 'Kategori'),
                items: [
                  for (final cat in cats)
                    DropdownMenuItem(
                        value: cat.id,
                        child: Text('${cat.icon} ${cat.name}')),
                ],
                onChanged: (v) => setS(() => catId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Batas (Rp)',
                  hintText: 'cth. 1.500.000',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    final limit = parseRp(limitCtrl.text);
    if (ok == true && catId != null && limit > 0) {
      await upsertBudget(ref,
          categoryId: catId!, limit: limit, month: month);
    }
  }
}

/// Ringkasan bulan: total batas, total terpakai, progress.
/// Perhitungan sama (jumlah limit & spent), hanya presentasi.
class _OverviewCard extends ConsumerWidget {
  const _OverviewCard({required this.list});
  final List<({Budget budget, String name, String icon, int spent})> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final totalLimit =
        list.fold<int>(0, (s, e) => s + e.budget.limit);
    final totalSpent = list.fold<int>(0, (s, e) => s + e.spent);
    final pct = totalLimit == 0
        ? 0.0
        : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final over = totalSpent > totalLimit;
    final color = over
        ? scheme.error
        : pct >= 0.8
            ? scheme.tertiary
            : scheme.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anggaran Bulan Ini',
              style: AppType.labelMuted(context)),
          const SizedBox(height: AppSpacing.s4),
          Text(display.money(totalLimit),
              style: AppType.balance(context)),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${display.money(totalSpent)} terpakai'
            '${over ? ' · lewat ${(100 * totalSpent / totalLimit).round()}%' : ''}',
            style: AppType.secondary(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppProgress(value: pct, color: color),
        ],
      ),
    );
  }
}

/// Satu item budget: ikon + nama + nominal + progress + sisa/hapus.
/// Threshold & warna sama dengan logika lama
/// (over = error, >=80% = tertiary, else primary).
class _BudgetItem extends ConsumerWidget {
  const _BudgetItem({required this.item, required this.onDelete});
  final ({Budget budget, String name, String icon, int spent}) item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final b = item;
    final pct = b.budget.limit == 0
        ? 0.0
        : (b.spent / b.budget.limit).clamp(0.0, 1.0);
    final over = b.spent > b.budget.limit;
    final color = over
        ? scheme.error
        : pct >= 0.8
            ? scheme.tertiary
            : scheme.primary;
    final remain = b.budget.limit - b.spent;
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          CategoryIcon(icon: b.icon, size: 36, fontSize: 18),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(b.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppSpacing.s4),
                        child: Icon(Icons.delete_outline,
                            size: 18,
                            color: AppColors.mutedOf(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${display.money(b.spent)} / ${display.money(b.budget.limit)}',
                  style: AppType.secondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                AppProgress(value: pct, color: color),
                const SizedBox(height: 4),
                Text(
                  over
                      ? 'Lewat ${display.money(-remain)} (${(100 * b.spent / b.budget.limit).round()}%)'
                      : '${display.money(remain)} tersisa · ${(pct * 100).round()}%',
                  style: AppType.secondary(context).copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
