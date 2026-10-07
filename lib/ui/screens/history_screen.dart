import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../components/app_card.dart';
import '../components/category_icon.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../format.dart';
import '../widgets/tx_tile.dart';
import 'tx_form_screen.dart';

/// Layar riwayat + filter (kategori, tipe, kata kunci).
///
/// STEP 2 — hanya UI/presentasi yang diubah. Logika TETAP:
/// search, month navigation, filter, list, tap/edit, loading,
/// empty state, provider & data transaksi tidak disentuh.
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: _Header(
                onPickMonth: () => _pickMonth(context, month),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            _MonthNav(
              month: month,
              onShift: (d) => ref
                  .read(selectedMonthProvider.notifier)
                  .state = shiftMonth(month, d),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.s8, AppSpacing.page, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari transaksi...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: filter.keyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                    .read(historyFilterProvider.notifier)
                                    .state =
                                HistoryFilter(
                              categoryId: filter.categoryId,
                              isExpense: filter.isExpense,
                            );
                          },
                        )
                      : null,
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
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page, vertical: AppSpacing.s8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: filter.isExpense == null,
                    onTap: () => _setFilter(filter, null),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  _FilterChip(
                    label: 'Pemasukan',
                    selected: filter.isExpense == false,
                    onTap: () => _setFilter(filter, false),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  _FilterChip(
                    label: 'Pengeluaran',
                    selected: filter.isExpense == true,
                    onTap: () => _setFilter(filter, true),
                  ),
                  cats.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (list) => Row(
                      children: [
                        if (list.isNotEmpty)
                          const SizedBox(width: AppSpacing.s8),
                        for (final c in list) ...[
                          _FilterChip(
                            label: '${c.icon} ${c.name}',
                            selected: filter.categoryId == c.id,
                            onTap: () {
                              final cur =
                                  ref.read(historyFilterProvider);
                              ref
                                      .read(
                                          historyFilterProvider.notifier)
                                      .state = HistoryFilter(
                                categoryId:
                                    cur.categoryId == c.id ? null : c.id,
                                isExpense: cur.isExpense,
                                keyword: cur.keyword,
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.s8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.when(
                loading: () => const _LoadingState(),
                error: (e, s) => Center(
                    child: Text('Gagal memuat: $e',
                        style: AppType.secondary(context))),
                data: (list) {
                  if (list.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (context, i) =>
                        const Divider(height: 1),
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

/// Judul layar + tombol kalender — bahasa yang sama dengan header Beranda.
class _Header extends StatelessWidget {
  const _Header({required this.onPickMonth});
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Riwayat', style: AppType.screenTitle(context)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: IconButton(
            onPressed: onPickMonth,
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            tooltip: 'Pilih bulan',
            constraints:
                const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Navigasi bulan — sama persis dengan Beranda.
class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.month, required this.onShift});
  final String month;
  final void Function(int) onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          icon: const Icon(Icons.chevron_left),
          constraints:
              const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
        Text(monthLabel(month),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: () => onShift(1),
          icon: const Icon(Icons.chevron_right),
          constraints:
              const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Chip filter kompak: jelas saat aktif, tenang saat tidak.
/// Bukan pil besar — radius 10 mengikuti token.
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : AppColors.borderOf(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: const [
        AppCard(
          child: Column(
            children: [
              _LoadingBar(),
              _LoadingBar(),
              _LoadingBar(),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: LinearProgressIndicator(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CategoryIcon(icon: '🧾', size: 56, fontSize: 28),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Belum ada transaksi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Belum ada transaksi untuk periode/filter ini.',
              textAlign: TextAlign.center,
              style: AppType.secondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
