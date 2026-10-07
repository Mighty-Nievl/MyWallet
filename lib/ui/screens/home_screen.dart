import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../display.dart';
import '../format.dart';
import '../widgets/tx_tile.dart';
import 'settings_screen.dart';
import 'tx_form_screen.dart';

/// Beranda: saldo, ringkasan hari ini, ringkasan bulan ini, top kategori,
/// transaksi terakhir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final balance = ref.watch(balanceProvider);
    final totals = ref.watch(monthTotalsProvider);
    final dayTotals = ref.watch(dayTotalsProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);
    final showTop = ref.watch(showTopCategoriesProvider).value ?? true;
    final showDaily = ref.watch(showDailyTotalsProvider).value ?? true;
    final showRecent = ref.watch(showRecentProvider).value ?? true;
    final recentCount = ref.watch(recentCountProvider).value ?? 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyWallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthNav(
            month: month,
            onShift: (d) => ref.read(selectedMonthProvider.notifier).state =
                shiftMonth(month, d),
          ),
          const SizedBox(height: 12),
          _BalanceCard(balance: balance, totals: totals),
          if (showDaily) ...[
            const SizedBox(height: 16),
            Text('Hari ini',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _DailyCard(dayTotals: dayTotals),
          ],
          if (showTop) ...[
            const SizedBox(height: 16),
            Text('Pengeluaran bulan ini',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            byCat.when(
              loading: () => const _Skeleton(lines: 3),
              error: (e, _) => Text('Gagal memuat: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada pengeluaran bulan ini.'),
                    ),
                  );
                }
                final max = list.first.total;
                return Card(
                  child: Column(
                    children: [
                      for (final c in list.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text(c.icon,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: max == 0
                                          ? 0
                                          : (c.total / max).clamp(0.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(display.money(c.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (showRecent) ...[
            const SizedBox(height: 16),
            Text('Terakhir dicatat',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _RecentList(count: recentCount),
          ],
        ],
      ),
    );
  }
}

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
        ),
        Text(monthLabel(month),
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: () => onShift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance, required this.totals});
  final AsyncValue<int> balance;
  final AsyncValue<(int, int)> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final showTotals = ref.watch(showMonthTotalsProvider).value ?? true;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Saldo saat ini',
                    style: TextStyle(color: scheme.onPrimaryContainer)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    hide ? Icons.visibility_off : Icons.visibility,
                    color: scheme.onPrimaryContainer,
                  ),
                  tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  onPressed: () => ref
                      .read(settingsServiceProvider)
                      .setHideBalance(!hide),
                ),
              ],
            ),
            balance.when(
              loading: () => const Text('…',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              error: (e, _) => Text('Error: $e'),
              data: (b) => Text(hide ? 'Rp••••••' : display.money(b),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            if (showTotals) const SizedBox(height: 12),
            if (showTotals)
              totals.when(
                loading: () => const Text('Memuat ringkasan…'),
                error: (e, _) => Text('Error: $e'),
                data: (t) => Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Masuk',
                        value: display.signed(t.$1, isExpense: false),
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Keluar',
                        value: display.signed(t.$2, isExpense: true),
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// Kartu ringkasan HARI INI: masuk / keluar / selisih + jumlah transaksi.
/// Ikut privacy scope 'all' (nominal jadi Rp••••) + nominal ringkas.
class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.dayTotals});
  final AsyncValue<(int, int)> dayTotals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final display = ref.watch(displayPrefsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: dayTotals.when(
          loading: () => const _Skeleton(lines: 2),
          error: (e, _) => Text('Gagal memuat: $e'),
          data: (t) {
            final net = t.$1 - t.$2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDate(DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Masuk',
                        value:
                            display.signed(t.$1, isExpense: false),
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Keluar',
                        value: display.signed(t.$2, isExpense: true),
                        color: scheme.error,
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Selisih',
                        value: display.signed(net.abs(),
                            isExpense: net < 0),
                        color: net < 0
                            ? scheme.error
                            : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return StreamBuilder<List<TxWithCategory>>(
      stream: db.watchHistory(limit: count),
      builder: (context, snap) {
        if (!snap.hasData) return const _Skeleton(lines: 3);
        final list = snap.data!;
        if (list.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Belum ada transaksi. Ketuk tombol "Catat" untuk mulai.'),
            ),
          );
        }
        return Card(
          child: Column(
            children: [
              for (final tx in list)
                TxTile(
                  tx: tx,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TxFormScreen(existing: tx)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.lines});
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            lines,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}
