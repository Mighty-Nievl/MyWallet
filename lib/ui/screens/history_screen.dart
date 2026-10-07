import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../format.dart';
import '../widgets/tx_tile.dart';
import 'tx_form_screen.dart';

/// Layar riwayat + filter (kategori, tipe, kata kunci).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final history = ref.watch(historyProvider);
    final cats = ref.watch(categoriesProvider);
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat · ${monthLabel(month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: monthLabel(month),
            onPressed: () => _pickMonth(context, month),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari catatan…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(historyFilterProvider.notifier).state =
                              HistoryFilter(
                            categoryId: filter.categoryId,
                            isExpense: filter.isExpense,
                          );
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(historyFilterProvider.notifier).state =
                      HistoryFilter(
                categoryId: filter.categoryId,
                isExpense: filter.isExpense,
                keyword: v,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _Chip(
                  label: 'Semua',
                  selected: filter.isExpense == null,
                  onTap: () => _setFilter(filter, null),
                ),
                _Chip(
                  label: 'Keluar',
                  selected: filter.isExpense == true,
                  onTap: () => _setFilter(filter, true),
                ),
                _Chip(
                  label: 'Masuk',
                  selected: filter.isExpense == false,
                  onTap: () => _setFilter(filter, false),
                ),
                const SizedBox(width: 8),
                cats.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (list) => Row(
                    children: [
                      for (final c in list)
                        _Chip(
                          label: '${c.icon} ${c.name}',
                          selected: filter.categoryId == c.id,
                          onTap: () {
                            final cur =
                                ref.read(historyFilterProvider);
                            ref
                                .read(historyFilterProvider.notifier)
                                .state = HistoryFilter(
                              categoryId:
                                  cur.categoryId == c.id ? null : c.id,
                              isExpense: cur.isExpense,
                              keyword: cur.keyword,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Gagal memuat: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada transaksi yang cocok.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (context, i) => TxTile(
                    tx: list[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) =>
                            TxFormScreen(existing: list[i]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setFilter(HistoryFilter base, bool? type) {
    ref.read(historyFilterProvider.notifier).state = HistoryFilter(
      categoryId: base.categoryId,
      isExpense: type,
      keyword: base.keyword,
    );
  }

  Future<void> _pickMonth(BuildContext context, String current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        int.parse(current.split('-')[0]),
        int.parse(current.split('-')[1]),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = monthKey(picked);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) => onTap(),
      ),
    );
  }
}
