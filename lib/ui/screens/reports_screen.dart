import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/report_pdf_service.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';

/// Layar laporan: ringkasan bulan + grafik 6 bulan + rincian kategori.
///
/// STEP 3 — hanya UI/presentasi yang diubah. Logika TETAP:
/// fl_chart tetap, data bar 6 bulan (getTotals), pie + rincian
/// (totalsByCategory), total, month provider, display prefs.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final totals = ref.watch(monthTotalsProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            AppSpacing.bottomPad,
          ),
          children: [
            AppHeader(
              title: 'Laporan',
              actionIcon: Icons.picture_as_pdf_outlined,
              actionTooltip: 'Export PDF bulan ini',
              onAction: () => _exportPdf(context, ref, month),
            ),
            const SizedBox(height: AppSpacing.s8),
            AppMonthNav(
              month: month,
              onShift: (d) => ref
                  .read(selectedMonthProvider.notifier)
                  .state = shiftMonth(month, d),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppSection(
              title: 'Ringkasan bulan ini',
              child: _SummaryCard(totals: totals),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppSection(
              title: 'Arus 6 bulan terakhir',
              child: AppCard(
                child: SizedBox(height: 220, child: _SixMonthChart()),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppSection(
              title: 'Rincian bulan ini',
              child: _Breakdown(
                  byCat: byCat, display: display),
            ),
          ],
        ),
      ),
    );
  }

  /// Export PDF bulan aktif: tanya Simpan-file vs Bagikan dulu,
  /// lalu panggil [ReportPdfService]. 100% lokal, tanpa server.
  static Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    String month,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Bagikan PDF'),
              subtitle: const Text('Lewat share sheet (cepat)'),
              onTap: () => Navigator.pop(c, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Simpan ke file'),
              subtitle: const Text('Pilih folder sendiri'),
              onTap: () => Navigator.pop(c, 'save'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    try {
      if (choice == 'save') {
        final uri =
            await ReportPdfService.saveMonthPdfToFile(ref, monthKey: month);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uri == null
                ? 'Simpan PDF dibatalkan.'
                : 'PDF laporan tersimpan.'),
          ),
        );
      } else {
        final count =
            await ReportPdfService.exportMonthPdf(ref, monthKey: month);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF dibuat: $count transaksi.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export PDF gagal — coba lagi.'),
          ),
        );
      }
    }
  }
}

/// Ringkasan: Pemasukan / Pengeluaran / Selisih bulan berjalan.
/// Nilai dari monthTotalsProvider — sama seperti Beranda.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.totals});
  final AsyncValue<(int, int)> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final display = ref.watch(displayPrefsProvider);
    return AppCard(
      child: totals.when(
        loading: () => const AppSkeleton(lines: 2),
        error: (e, _) => AppErrorState(
          title: 'Ringkasan gagal dimuat.',
          onRetry: () => ref.invalidate(monthTotalsProvider),
        ),
        data: (t) {
          final net = t.$1 - t.$2;
          return Row(
            children: [
              Expanded(
                child: _SumItem(
                  label: 'Pemasukan',
                  value: display.signed(t.$1, isExpense: false),
                  color: scheme.primary,
                ),
              ),
              Expanded(
                child: _SumItem(
                  label: 'Pengeluaran',
                  value: display.signed(t.$2, isExpense: true),
                  color: scheme.error,
                ),
              ),
              Expanded(
                child: _SumItem(
                  label: 'Selisih',
                  value: display.signed(net.abs(),
                      isExpense: net < 0),
                  color: net < 0 ? scheme.error : scheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  const _SumItem(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.labelMuted(context)),
        const SizedBox(height: 2),
        Text(value,
            style: AppType.amount(context).copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Rincian kategori: pie + daftar konsisten dengan Beranda.
/// Perhitungan & total sama dengan implementasi lama.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.byCat, required this.display});
  final AsyncValue<List<CategoryTotal>> byCat;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context) {
    return byCat.when(
      loading: () =>
          const AppCard(child: AppSkeleton(lines: 3)),
      error: (e, _) => const AppErrorState(
        title: 'Rincian gagal dimuat.',
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '📊',
            title: 'Belum ada data laporan',
            subtitle: 'Belum ada transaksi pada periode ini.',
          );
        }
        final total = list.fold<int>(0, (s, e) => s + e.total);
        return Column(
          children: [
            AppCard(
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      for (var i = 0;
                          i < list.length && i < 6;
                          i++)
                        PieChartSectionData(
                          value: list[i].total.toDouble(),
                          title:
                              '${(100 * list[i].total / total).round()}%',
                          radius: 70,
                          color: _pieColors[
                              i % _pieColors.length],
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            for (final c in list)
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s8),
                child: Row(
                  children: [
                    if (display.showIcons)
                      CategoryGlyph(
                          emoji: c.icon, size: 36, iconSize: 18),
                    if (display.showIcons)
                      const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(c.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${(100 * c.total / total).round()}% · ${display.money(c.total)}',
                      style: AppType.amount(context, size: 14),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total keluar: ${display.money(total)}',
                style: AppType.amount(context, size: 14),
              ),
            ),
          ],
        );
      },
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
    final muted = scheme.onSurfaceVariant;
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _short(parts[1]),
                        style:
                            TextStyle(fontSize: 12, color: muted),
                      ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                  BarChartRodData(
                    toY: rows[i].$2.toDouble(), // masuk
                    color: scheme.primary,
                    width: 8,
                    borderRadius: BorderRadius.circular(2),
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
