import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/period.dart';
import '../../data/providers.dart';
import '../components/app_card.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';

/// Kalender bulanan dengan total masuk/keluar per hari (v1.36.0).
///
/// Bukan jenis periode baru: kalender adalah ALAT NAVIGASI. Ketuk satu
/// tanggal → periode aktif jadi Harian di tanggal itu, lalu layar ditutup.
/// Bulan yang dibuka mengikuti periode aktif (bulan berjalan bila periode
/// memuat hari ini; selain itu bulan awal periode), jadi tidak ada
/// kejutan "kok kalendernya beda bulan".
///
/// Data per hari datang dari [calendarDailyTotalsProvider] (satu query
/// per bulan, agregasi lokal). Transfer antar dompet sengaja tidak
/// dihitung — sama dengan total di Laporan/Riwayat.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final period = ref.read(activePeriodProvider);
    final now = DateTime.now();
    _month = period.containsToday()
        ? DateTime(now.year, now.month, 1)
        : DateTime(period.start.year, period.start.month, 1);
  }

  String get _monthKey => monthKey(_month);

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    if (next.isAfter(current)) return;
    HapticFeedback.selectionClick();
    setState(() => _month = next);
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month, 1));
  }

  void _pick(DateTime day) {
    HapticFeedback.selectionClick();
    ref.read(periodKindProvider.notifier).state = PeriodKind.harian;
    ref.read(periodAnchorProvider.notifier).state = DateTime(
      day.year,
      day.month,
      day.day,
    );
    // Jaga konteks bulanan sejalan: kalau user kembali ke Bulanan, bulan
    // yang dibuka di kalender (bukan bulan lama) yang tampil.
    ref.read(selectedMonthProvider.notifier).state = monthKey(day);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final daily = ref.watch(calendarDailyTotalsProvider(_monthKey));
    final display = ref.watch(displayPrefsProvider);
    final active = ref.watch(activePeriodProvider);

    var masuk = 0;
    var keluar = 0;
    for (final total
        in (daily.value ?? const <DateTime, (int, int)>{}).values) {
      masuk += total.$1;
      keluar += total.$2;
    }

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
              title: 'Kalender',
              actionIcon: Icons.today_outlined,
              actionTooltip: 'Bulan ini',
              onAction: _goToday,
              onBack: Navigator.of(context).pop,
            ),
            const SizedBox(height: AppSpacing.s8),
            AppMonthNav(month: _monthKey, onShift: _shift),
            const SizedBox(height: AppSpacing.s8),
            _MonthSummary(masuk: masuk, keluar: keluar, display: display),
            const SizedBox(height: AppSpacing.s12),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: _MonthGrid(
                  month: _month,
                  daily: daily,
                  display: display,
                  active: active,
                  onPick: _pick,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Ketuk tanggal untuk melihat rincian harian.',
              textAlign: TextAlign.center,
              style: AppType.labelMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dua angka ringkas bulan yang sedang dibuka.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.masuk,
    required this.keluar,
    required this.display,
  });

  final int masuk;
  final int keluar;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            label: 'Masuk',
            amount: display.money(masuk),
            color: AppColors.incomeOf(context),
            icon: Icons.south_west,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _SummaryPill(
            label: 'Keluar',
            amount: display.money(keluar),
            color: AppColors.expenseOf(context),
            icon: Icons.north_east,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppType.labelMuted(context)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    maxLines: 1,
                    style: AppType.amount(context)
                        .copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid 7 kolom, pekan mulai Senin (konsisten dengan [Period]).
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.daily,
    required this.display,
    required this.active,
    required this.onPick,
  });

  final DateTime month;
  final AsyncValue<Map<DateTime, (int, int)>> daily;
  final DisplayPrefs display;
  final Period active;
  final ValueChanged<DateTime> onPick;

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Senin = 0
    final cells = leading + daysInMonth;
    final rows = (cells + 6) ~/ 7;
    final today = DateTime.now();
    final totals = daily.value ?? const <DateTime, (int, int)>{};

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppType.labelMuted(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        for (var row = 0; row < rows; row++)
          SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _cell(
                      context,
                      row: row,
                      col: col,
                      leading: leading,
                      daysInMonth: daysInMonth,
                      totals: totals,
                      today: today,
                    ),
                  ),
              ],
            ),
          ),
        if (daily.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context, {
    required int row,
    required int col,
    required int leading,
    required int daysInMonth,
    required Map<DateTime, (int, int)> totals,
    required DateTime today,
  }) {
    final index = row * 7 + col;
    final dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox.shrink();
    }
    final date = DateTime(month.year, month.month, dayNumber);
    final total = totals[date] ?? (0, 0);
    return _DayCell(
      date: date,
      masuk: total.$1,
      keluar: total.$2,
      display: display,
      isToday: _sameDay(date, today),
      isActive:
          active.kind == PeriodKind.harian && _sameDay(active.start, date),
      onTap: () => onPick(date),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.masuk,
    required this.keluar,
    required this.display,
    required this.isToday,
    required this.isActive,
    required this.onTap,
  });

  final DateTime date;
  final int masuk;
  final int keluar;
  final DisplayPrefs display;
  final bool isToday;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = AppColors.incomeOf(context);
    final expense = AppColors.expenseOf(context);
    final semantics = <String>[
      formatDateLong(date),
      if (masuk > 0) 'masuk ${display.money(masuk)}',
      if (keluar > 0) 'keluar ${display.money(keluar)}',
    ];

    return Semantics(
      button: true,
      label: semantics.join(', '),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isActive ? scheme.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.smAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey(
              'calendar:day:${date.year}-${date.month}-${date.day}',
            ),
            customBorder: const RoundedRectangleBorder(
              borderRadius: AppRadius.smAll,
            ),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
              decoration: BoxDecoration(
                borderRadius: AppRadius.smAll,
                border: isToday && !isActive
                    ? Border.all(color: scheme.primary, width: 1)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.day}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: isToday || isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isActive
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (masuk > 0)
                    _Amount(text: display.compact(masuk), color: income),
                  if (keluar > 0)
                    _Amount(text: display.compact(keluar), color: expense),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 9,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ).copyWith(color: color),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
