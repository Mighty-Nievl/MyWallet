import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../display.dart';
import '../format.dart';

/// Layar laporan: grafik 6 bulan + rincian kategori bulan berjalan.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Laporan · ${monthLabel(month)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Arus 6 bulan terakhir',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(height: 220, child: _SixMonthChart()),
            ),
          ),
          const SizedBox(height: 16),
          Text('Rincian bulan ini',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          byCat.when(
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator())),
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
              final total = list.fold<int>(0, (s, e) => s + e.total);
              return Card(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            for (var i = 0; i < list.length && i < 6; i++)
                              PieChartSectionData(
                                value: list[i].total.toDouble(),
                                title:
                                    '${(100 * list[i].total / total).round()}%',
                                radius: 70,
                                color: _pieColors[
                                    i % _pieColors.length],
                              ),
                          ],
                        ),
                      ),
                    ),
                    for (final c in list)
                      ListTile(
                        leading: display.showIcons
                            ? Text(c.icon,
                                style:
                                    const TextStyle(fontSize: 20))
                            : null,
                        title: Text(c.name),
                        trailing: Text(display.money(c.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Total keluar: ${display.money(total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Palet pie: SENGAJA fix 6 warna (jangan ikut aksen) agar kategori A
/// selalu warna sama tiap bulan + potongan mudah dibedakan.
/// Tanpa hijau (hijau = warna pemasukan/aksen default, biar tidak ambigu).
const _pieColors = [
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];

class _SixMonthChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<(String, int, int)>>(
      future: _lastSixMonths(db),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        final maxY = rows.fold<double>(
            1000, (m, r) => r.$2 > m ? r.$2.toDouble() : m);
        return BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    final parts = rows[i].$1.split('-');
                    return Text(
                      _short(parts[1]),
                      style: const TextStyle(fontSize: 11),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < rows.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: rows[i].$3.toDouble(), // keluar
                    color: scheme.error,
                    width: 8,
                  ),
                  BarChartRodData(
                    toY: rows[i].$2.toDouble(), // masuk
                    color: scheme.primary,
                    width: 8,
                  ),
                ]),
            ],
          ),
        );
      },
    );
  }

  Future<List<(String, int, int)>> _lastSixMonths(AppDatabase db) async {
    final now = DateTime.now();
    final out = <(String, int, int)>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final from = DateTime(d.year, d.month, 1);
      final to =
          DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1));
      final (masuk, keluar) = await db.getTotals(from, to);
      out.add((monthKey(d), masuk, keluar));
    }
    return out;
  }

  String _short(String m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final i = int.tryParse(m) ?? 0;
    return (i >= 1 && i <= 12) ? names[i] : m;
  }
}
