import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/report_pdf_service.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../components/period_switcher.dart';
import '../design/app_motion.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../widgets/account_picker.dart';

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
    // v1.35.0: angka utama ikut PERIODE aktif (harian/mingguan/bulanan/
    // tahunan), bukan selalu bulan. `monthTotals` tetap dipakai khusus
    // untuk blok grafik 6 bulan + strip wawasan — keduanya memang bulanan
    // dan diberi judul jujur supaya tidak tampak salah konteks.
    final period = ref.watch(activePeriodProvider);
    final totals = ref.watch(periodTotalsProvider);
    final byCat = ref.watch(periodExpenseByCategoryProvider);
    final monthTotals = ref.watch(monthTotalsProvider);
    final monthPrev = ref.watch(prevMonthTotalsProvider);
    final display = ref.watch(displayPrefsProvider);
    // v1.30: suffix dompet utk judul section (jujur: angka milik siapa).
    final acctSuffix = _accountSuffix(ref);

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
              // v1.26: dibuka via push dari grid Beranda (bukan tab).
              onBack: Navigator.of(context).pop,
            ),
            const SizedBox(height: AppSpacing.s8),
            // v1.35.0: switcher periode + navigasi geser per unit.
            // Menggantikan AppMonthNav: bulan hanyalah salah satu periode.
            const PeriodSwitcher(),
            const SizedBox(height: AppSpacing.s8),
            PeriodNav(period: period),
            // v1.25: filter dompet global (tanpa Kelola — hemat vertikal;
            // kelola milik Beranda). Semua angka ikut via provider.
            const SizedBox(height: AppSpacing.s8),
            const AccountPicker(),
            const SizedBox(height: AppSpacing.s16),
            // B2C v1.20: entrance stagger per seksi — teks/key/logika tetap.
            // v1.24.11: Selisih = hero (jawaban), Masuk/Keluar = bahan.
            // Section title JUJUR: dinamis ikut bulan yang dilihat.
            Stagger(
              index: 0,
              child: AppSection(
                title: 'Ringkasan ${periodLabel(period)}$acctSuffix',
                child: _SummaryCard(totals: totals),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Stagger(
              index: 1,
              child: AppSection(
                // v1.35.0: judul menyebut "bulanan" secara eksplisit —
                // grafik ini SELALU bulanan, walau periode aktif mingguan.
                title: 'Arus 6 bulan terakhir (bulanan)',
                // v1.24.11: legenda ditaruh di trailing judul (nempel
                // grafik, tak makan tinggi kartu) + strip wawasan.
                trailing: const _ChartLegend(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: SizedBox(height: 220, child: _SixMonthChart()),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _InsightStrip(
                      // Strip wawasan membandingkan BULAN berjalan vs bulan
                      // lalu → sengaja pakai totals bulanan, bukan periode.
                      totals: monthTotals,
                      prevTotals: monthPrev,
                      month: month,
                      display: display,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Stagger(
              index: 2,
              child: AppSection(
                title: 'Rincian ${periodLabel(period)}$acctSuffix',
                child: _Breakdown(byCat: byCat, display: display),
              ),
            ),
          ],
        ),
      ),
    );
  }

/// Suffix judul jujur dompet (v1.30 — label dompet di Laporan).
/// null (Semua) = tanpa suffix; spesifik = ` · Nama`.
/// Cermin [accountTitleSuffix] Beranda: 1 dompet = tanpa suffix.
String _accountSuffix(WidgetRef ref) {
  final id = ref.watch(selectedAccountProvider);
  final accs = ref.watch(accountsProvider).value ?? const <Account>[];
  if (id == null || accs.length <= 1) return '';
  for (final a in accs) {
    if (a.id == id) return ' · ${a.name}';
  }
  return '';
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
    // B2C v1.20: haptic saat pilihan export dikunci.
    HapticFeedback.selectionClick();
    try {
      if (choice == 'save') {
        final uri = await ReportPdfService.saveMonthPdfToFile(
          ref,
          monthKey: month,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uri == null ? 'Simpan PDF dibatalkan.' : 'PDF laporan tersimpan.',
            ),
          ),
        );
      } else {
        final count = await ReportPdfService.exportMonthPdf(
          ref,
          monthKey: month,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF dibuat: $count transaksi.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export PDF gagal — coba lagi.')),
        );
      }
    }
  }
}

/// Ringkasan: Selisih = HERO (jawaban), Masuk/Keluar = bahan.
/// Nilai dari monthTotalsProvider — sama seperti Beranda.
///
/// v1.24.11 (audit L3): tiga kolom identik 1:1:1 bikin mata tak tahu
/// mendarat di mana. Kini Selisih 20px semibold di atas (raja),
/// Masuk/Keluar 13px di bawah (pelayan). Hierarki, bukan uniform.
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
          final good = net >= 0;
          final heroColor = good ? scheme.primary : scheme.error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selisih', style: AppType.labelMuted(context)),
              const SizedBox(height: AppSpacing.micro),
              // Hero angka: satu-satunya 20px di seksi ini.
              Text(
                display.signed(net.abs(), isExpense: net < 0),
                style: AppType.amount(
                  context,
                  size: 20,
                ).copyWith(color: heroColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
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
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Strip wawasan SATU baris (v1.24.11 audit L5: Laporan arsip → jawaban).
/// Murni presentasi dari (totals, prevTotals) — tanpa query sendiri.
/// Aturan jujur: bulan lalu NOL + bulan ini ADA = "mulai ada ...",
/// BUKAN "naik ∞%". Dua-duanya nol = sembunyi (nol insight, nol klaim).
class _InsightStrip extends StatelessWidget {
  const _InsightStrip({
    required this.totals,
    required this.prevTotals,
    required this.month,
    required this.display,
  });
  final AsyncValue<(int, int)> totals;
  final AsyncValue<(int, int)> prevTotals;
  final String month;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Riverpod 3.4.3: AsyncValue pakai `.value` (valueOrNull tak ada —
    // pelajaran v1.24.9). Loading/error/salah satu belum ada → sembunyi.
    final now = totals.value;
    final prev = prevTotals.value;
    if (now == null || prev == null) return const SizedBox.shrink();
    final text = insightText(
      keluar: now.$2,
      prevKeluar: prev.$2,
      prevLabel: _prevShort(month),
      money: display.money,
    );
    if (text == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.insights_outlined, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: AppType.secondary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Kalimat wawasan murni (v1.24.11): dipisah agar unit-testable tanpa UI.
/// Kembalikan null = tak ada wawasan → strip sembunyi.
String? insightText({
  required int keluar,
  required int prevKeluar,
  required String prevLabel,
  required String Function(int) money,
}) {
  if (keluar == 0 && prevKeluar == 0) return null;
  if (prevKeluar == 0) return 'Mulai ada pengeluaran: ${money(keluar)}.';
  if (keluar == prevKeluar) {
    return 'Pengeluaran sama dengan $prevLabel: ${money(keluar)}.';
  }
  final diff = keluar - prevKeluar;
  final pct = (diff.abs() * 100 / prevKeluar).round();
  final arah = diff > 0 ? 'naik' : 'turun';
  return 'Keluar $arah $pct% vs $prevLabel (${money(prevKeluar)} → ${money(keluar)}).';
}

/// "2026-10" → "Sep" (label bulan SEBELUMNYA, pendek untuk strip).
String _prevShort(String month) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final parts = month.split('-');
  final y = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (y == 0 || m < 1 || m > 12) return 'bulan lalu';
  final p = DateTime(y, m - 1, 1);
  return names[p.month];
}

/// Legenda grafik di trailing judul seksi (v1.24.11 audit L4):
/// hijau = Masuk, merah = Keluar. Nempel judul → nol tinggi kartu.
class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(label, style: AppType.secondary(context)),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(scheme.primary, 'Masuk'),
        const SizedBox(width: AppSpacing.s12),
        dot(scheme.error, 'Keluar'),
      ],
    );
  }
}

class _SumItem extends StatelessWidget {
  const _SumItem({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.labelMuted(context)),
        const SizedBox(height: AppSpacing.micro),
        Text(
          value,
          style: AppType.amount(context).copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
      loading: () => const AppCard(child: AppSkeleton(lines: 3)),
      error: (e, _) => const AppErrorState(title: 'Rincian gagal dimuat.'),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '📊',
            title: 'Belum ada data laporan',
            subtitle: 'Belum ada transaksi pada periode ini.',
          );
        }
        final total = list.fold<int>(0, (s, e) => s + e.total);
        // v1.24.11 (audit L4): pie jujur — warna iris == dot di list
        // (satu sumber _pieColors, sinkron indeks), iris <=3% tanpa
        // label % (angka kecil di iris kecil tak terbaca), footnote
        // bila kategori > 6 (sisanya tak digambar, user wajib tahu).
        const shown = 6;
        final visCount = list.length < shown ? list.length : shown;
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
                      for (var i = 0; i < visCount; i++)
                        PieChartSectionData(
                          value: list[i].total.toDouble(),
                          title: pieSliceLabel(list[i].total, total),
                          radius: 70,
                          color: _pieColors[i % _pieColors.length],
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
            // Legenda warna pie (nempel kartu, bukan di judul —
            // 6 dot tak muat di trailing). Sembunyi saat privacy.
            _PieLegend(
              list: list,
              visCount: visCount,
              total: total,
              display: display,
            ),
            const SizedBox(height: AppSpacing.s12),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Row(
                  children: [
                    if (display.showIcons)
                      CategoryGlyph(
                        emoji: list[i].icon,
                        size: 36,
                        iconSize: 18,
                      ),
                    if (display.showIcons)
                      const SizedBox(width: AppSpacing.s12),
                    // v1.24.11: dot warna pie sinkron indeks (i<6) —
                    // jembatan visual pie ↔ baris (audit L4).
                    if (i < visCount)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: _pieColors[i % _pieColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        list[i].name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(100 * list[i].total / total).round()}% · ${display.money(list[i].total)}',
                      style: AppType.amount(context, size: 14),
                    ),
                  ],
                ),
              ),
            // v1.24.11: footnote jujur bila ada kategori tak digambar.
            if (list.length > visCount)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menampilkan $visCount terbesar dari ${list.length} kategori.',
                  style: AppType.secondary(context),
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

/// Label % di DALAM iris (v1.24.11): iris <=3% tak berlabel
/// (angka putih di potongan kecil tak terbaca) — % tetap ada
/// di legenda + baris rincian. Murni, unit-testable (public agar
/// bisa diassert langsung dari test).
String pieSliceLabel(int part, int total) {
  if (total <= 0) return '';
  final pct = 100 * part / total;
  if (pct < 3.5) return '';
  return '${pct.round()}%';
}

/// Legenda warna pie (v1.24.11 audit L4: pie bisu → bernama).
/// Dot sinkron indeks iris + nama kategori. Saat privacy aktif,
/// nominal jadi Rp•••• (ikut display.money) — persen tetap tampil
/// (proporsi, bukan nilai). Wrap agar 6 item tak overflow 390px.
class _PieLegend extends StatelessWidget {
  const _PieLegend({
    required this.list,
    required this.visCount,
    required this.total,
    required this.display,
  });
  final List<CategoryTotal> list;
  final int visCount;
  final int total;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s4,
      children: [
        for (var i = 0; i < visCount; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _pieColors[i % _pieColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Text(
                '${list[i].name} ${(100 * list[i].total / total).round()}%',
                style: AppType.secondary(context),
              ),
            ],
          ),
      ],
    );
  }
}

class _SixMonthChart extends ConsumerWidget {
  const _SixMonthChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(sixMonthFlowProvider);
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return flow.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        title: 'Grafik gagal dimuat.',
        onRetry: () => ref.invalidate(sixMonthFlowProvider),
      ),
      data: (rows) {
        // v1.24.11 privacy: nominal disembunyi → batang RATA
        // (bentuk tren tetap, nilai tak terbaca). Tak ada bocor visual.
        final hidden = display.hide && display.scopeAll;
        final maxRaw = rows.fold<double>(
          1000,
          (m, r) => r.keluar > m ? r.keluar.toDouble() : m,
        );
        // Skala ikut data terbesar (masuk ATAU keluar) agar tak ada
        // bulan kerdil diam-diam saat gaji mendominasi.
        final maxBoth = rows.fold<double>(
          maxRaw,
          (m, r) => r.masuk > m ? r.masuk.toDouble() : m,
        );
        // Semantics: screen reader dengar ringkas tiap bulan (L1).
        final semLabel = rows
            .map(
              (r) =>
                  '${_short(r.key.split('-')[1])}: masuk ${display.money(r.masuk)}, keluar ${display.money(r.keluar)}',
            )
            .join('. ');
        return Semantics(
          label: 'Grafik arus 6 bulan. $semLabel',
          child: BarChart(
            BarChartData(
              maxY: (hidden ? 6 : maxBoth) * 1.2,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s4),
                        child: Text(
                          _short(rows[i].key.split('-')[1]),
                          style: TextStyle(fontSize: 12, color: muted),
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
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        // Keluar.
                        toY: hidden ? 5 : rows[i].keluar.toDouble(),
                        color: scheme.error,
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        // Masuk.
                        toY: hidden ? 5 : rows[i].masuk.toDouble(),
                        color: scheme.primary,
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _short(String m) {
    const names = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final i = int.tryParse(m) ?? 0;
    return (i >= 1 && i <= 12) ? names[i] : m;
  }
}
