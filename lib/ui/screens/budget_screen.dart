import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../amount_input.dart';
import '../display.dart';
import '../format.dart';

/// Layar budget bulanan per kategori.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final budgets = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget · ${monthLabel(month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref
                .read(selectedMonthProvider.notifier)
                .state = shiftMonth(month, -1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref
                .read(selectedMonthProvider.notifier)
                .state = shiftMonth(month, 1),
          ),
        ],
      ),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada budget bulan ini.\nTambahkan batas per kategori agar pengeluaran terkontrol.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          _showBudgetDialog(context, ref, month),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Budget'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final b in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(b.icon,
                                style:
                                    const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(b.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => deleteBudget(
                                  ref, b.budget.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final display = ref.watch(displayPrefsProvider);
                          final pct = b.budget.limit == 0
                              ? 0.0
                              : (b.spent / b.budget.limit)
                                  .clamp(0.0, 1.0);
                          final over = b.spent > b.budget.limit;
                          final scheme = Theme.of(context).colorScheme;
                          final color = over
                              ? scheme.error
                              : pct >= 0.8
                                  ? scheme.tertiary
                                  : scheme.primary;
                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                  value: pct,
                                  color: color,
                                  minHeight: 8),
                              const SizedBox(height: 8),
                              Text(
                                '${display.money(b.spent)} / ${display.money(b.budget.limit)}'
                                '${over ? ' · LEWAT ${(100 * b.spent / b.budget.limit).round()}%' : ' · ${(pct * 100).round()}%'}',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showBudgetDialog(context, ref, month),
                icon: const Icon(Icons.add),
                label: const Text('Tambah / Ubah Budget'),
              ),
            ],
          );
        },
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
