import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../widgets/tx_tile.dart';
import 'settings_screen.dart';
import 'tx_form_screen.dart';

/// Ambang waspada budget di hero (sama dengan layar Budget).
const _warnAt = 0.8;

/// Hero selalu gelap netral (terang maupun mode gelap) agar hirarki
/// konsisten. Di atasnya teks putih + varian semantik TERANG
/// (bukan primary/error mentah yang tenggelam di atas hitam).
/// Seluruh aplikasi lain tetap pakai scheme.primary/error.
const _heroBg = Color(0xFF171717);
const _heroText = Colors.white;
const _heroSoft = Color(0xB3FFFFFF);
const _heroWarn = Color(0xFFFBBF24);

/// Total pengeluaran BULAN SEBELUMNYA (delta % di hero).
/// Provider, bukan FutureBuilder di dalam build — query jalan sekali
/// per bulan terpilih, tidak diulang tiap rebuild.
final _prevMonthExpenseProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(dbProvider);
  final (from, to) =
      monthRangeOf(shiftMonth(ref.watch(selectedMonthProvider), -1));
  return (await db.getTotals(from, to)).$2;
});

/// Beranda: sapaan pinned, hero saldo + insight budget, strip hari ini,
/// top kategori proporsional, terakhir dikelompokkan per tanggal.
///
/// Header PINNED (di luar scroll) — pintu Pengaturan tidak pernah hilang.
/// Scroll: CustomScrollView dengan TEPAT SATU SliverToBoxAdapter per
/// section (berkunci ValueKey), baris memakai Column biasa.
///
/// Logika bisnis TETAP: provider, perhitungan, query, navigasi bulan,
/// navigasi ke Pengaturan & form tidak disentuh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onGoTab});

  /// Lompat tab shell (0=Beranda, 1=Riwayat, 2=Budget, 3=Laporan).
  final ValueChanged<int>? onGoTab;

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

    final now = DateTime.now();

    void shift(int d) => ref.read(selectedMonthProvider.notifier).state =
        shiftMonth(month, d);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _pad(
              AppHeader(
                title: _greeting(now.hour),
                subtitle: '${_weekday(now.weekday)}, ${formatDate(now)}',
                actionIcon: Icons.settings_outlined,
                actionTooltip: 'Pengaturan',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
              top: AppSpacing.s8,
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    key: const ValueKey('home:monthnav'),
                    child: _pad(
                      AppMonthNav(month: month, onShift: shift),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s16),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:balance'),
                    child: _pad(_BalanceCard(
                      balance: balance,
                      totals: totals,
                      month: month,
                      onOpenBudget:
                          onGoTab == null ? null : () => onGoTab!(2),
                    )),
                  ),
                  if (showDaily) ...[
                    const SliverToBoxAdapter(
                      child:
                          SizedBox(height: AppSpacing.sectionGap),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:daily'),
                      child: _pad(
                        AppSection(
                          title: 'Hari ini',
                          child: _DailyCard(dayTotals: dayTotals),
                        ),
                      ),
                    ),
                  ],
                  if (showTop) ...[
                    const SliverToBoxAdapter(
                      child:
                          SizedBox(height: AppSpacing.sectionGap),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:topcats'),
                      child: _pad(
                        AppSection(
                          title: 'Pengeluaran bulan ini',
                          trailing: onGoTab == null
                              ? null
                              : TextButton(
                                  onPressed: () => onGoTab!(3),
                                  child: const Text('Lihat semua'),
                                ),
                          child: _CategoryList(
                              byCat: byCat, display: display),
                        ),
                      ),
                    ),
                  ],
                  if (showRecent) ...[
                    const SliverToBoxAdapter(
                      child:
                          SizedBox(height: AppSpacing.sectionGap),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:recent'),
                      child: _pad(
                        AppSection(
                          title: 'Terakhir dicatat',
                          trailing: onGoTab == null
                              ? null
                              : TextButton(
                                  onPressed: () => onGoTab!(1),
                                  child: const Text('Lihat semua'),
                                ),
                          child: _RecentList(count: recentCount),
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.bottomPad),
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

/// Padding horizontal halaman untuk satu section.
Widget _pad(Widget child, {double top = 0}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(
        AppSpacing.page, top, AppSpacing.page, 0),
    child: child,
  );
}

String _greeting(int hour) {
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 19) return 'Selamat sore';
  return 'Selamat malam';
}

String _weekday(int w) {
  const names = [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];
  return (w >= 1 && w <= 7) ? names[w] : '';
}

/// Hero: saldo SEMUA WAKTU (label eksplisit, bukan "bulan ini") +
/// arus bulan berjalan (semantik terang) + delta vs bulan lalu +
/// pacing budget ("bulan ini aman nggak?").
///
/// Query tambahan hanya baca ulang via method DB yang sudah ada
/// (getTotals, budgetsProvider) — tidak ada logika baru.
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.balance,
    required this.totals,
    required this.month,
    required this.onOpenBudget,
  });
  final AsyncValue<int> balance;
  final AsyncValue<(int, int)> totals;
  final String month;

  /// Buka tab Budget (null bila dipakai tanpa shell, mis. di test).
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final showTotals =
        ref.watch(showMonthTotalsProvider).value ?? true;
    final budgets = ref.watch(budgetsProvider);

    // Border transparan di mode terang (layout identik antar tema),
    // #262626 di mode gelap agar hero tidak menyatu dengan latar #0A0A0A.
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: _heroBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.isDark(context)
              ? AppColors.darkBorder
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Saldo semua waktu',
                  style: AppType.labelMuted(context)
                      .copyWith(color: _heroSoft)),
              const Spacer(),
              IconButton(
                onPressed: () => ref
                    .read(settingsServiceProvider)
                    .setHideBalance(!hide),
                icon: Icon(
                  hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                tooltip:
                    hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                color: _heroSoft,
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    AppSpacing.touchMin,
                    AppSpacing.touchMin,
                  ),
                  foregroundColor: _heroSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          balance.when(
            loading: () => Text('…',
                style: AppType.balance(context)
                    .copyWith(color: _heroText)),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo gagal dimuat.',
                    style: AppType.balance(context)
                        .copyWith(color: _heroText, fontSize: 20)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(balanceProvider),
                  style: TextButton.styleFrom(
                      foregroundColor: _heroText),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
            data: (b) => Text(
              hide ? 'Rp••••••' : display.money(b),
              style: AppType.balance(context)
                  .copyWith(color: _heroText),
            ),
          ),
          if (showTotals) ...[
            const SizedBox(height: AppSpacing.s16),
            Container(
                height: 1, color: _heroText.withValues(alpha: 0.15)),
            const SizedBox(height: AppSpacing.s12),
            totals.when(
              loading: () => Text('Memuat ringkasan…',
                  style: AppType.secondary(context)
                      .copyWith(color: _heroSoft)),
              error: (e, _) => Text('Ringkasan gagal dimuat.',
                  style: AppType.secondary(context)
                      .copyWith(color: _heroSoft)),
              data: (t) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'Masuk ${monthLabel(month)}',
                          value: display.signed(t.$1,
                              isExpense: false),
                          labelColor: _heroSoft,
                          valueColor:
                              AppColors.incomeOnDark(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: _MiniStat(
                          label: 'Keluar ${monthLabel(month)}',
                          value: display.signed(t.$2,
                              isExpense: true),
                          labelColor: _heroSoft,
                          valueColor:
                              AppColors.expenseOnDark(context),
                        ),
                      ),
                    ],
                  ),
                  _DeltaVsPrev(
                      month: month, current: t.$2),
                  budgets.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (b) {
                      if (b.isEmpty) {
                        // Tanpa budget tetap ada ajakan: insight
                        // "aman nggak?" butuh angka yang diisi user.
                        if (onOpenBudget == null) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.s12),
                            Container(
                                height: 1,
                                color: _heroText
                                    .withValues(alpha: 0.15)),
                            const SizedBox(height: AppSpacing.s8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Belum ada budget bulan ini',
                                    style: AppType.secondary(
                                            context)
                                        .copyWith(
                                            color: _heroSoft),
                                  ),
                                ),
                                TextButton(
                                  onPressed: onOpenBudget,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _heroText,
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal:
                                            AppSpacing.s8),
                                    minimumSize: const Size(
                                        AppSpacing.touchMin, 36),
                                  ),
                                  child:
                                      const Text('Atur budget'),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      final limit = b.fold<int>(
                          0, (s, e) => s + e.budget.limit);
                      final spent = b.fold<int>(
                          0, (s, e) => s + e.spent);
                      final pct = limit == 0
                          ? 0.0
                          : (spent / limit).clamp(0.0, 1.0);
                      final over = spent > limit;
                      final warn = !over && pct >= _warnAt;
                      final barColor = over
                          ? AppColors.expenseOnDark(context)
                          : warn
                              ? _heroWarn
                              : AppColors.incomeOnDark(context);
                      final status = over
                          ? 'Lewat budget'
                          : warn
                              ? 'Hampir habis'
                              : 'Aman bulan ini';
                      final remain = limit - spent;
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                              height: AppSpacing.s12),
                          Container(
                              height: 1,
                              color: _heroText.withValues(
                                  alpha: 0.15)),
                          const SizedBox(
                              height: AppSpacing.s12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Budget ${monthLabel(month)}',
                                  style: AppType.secondary(
                                          context)
                                      .copyWith(
                                          color: _heroSoft),
                                ),
                              ),
                              Text(status,
                                  style: AppType.secondary(
                                          context)
                                      .copyWith(
                                    color: barColor,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                          const SizedBox(
                              height: AppSpacing.s8),
                          AppProgress(
                              value: pct,
                              color: barColor,
                              height: 8),
                          const SizedBox(
                              height: AppSpacing.s4),
                          Text(
                            over
                                ? '${display.money(-remain)} lewat dari ${display.money(limit)}'
                                : '${display.money(remain)} tersisa dari ${display.money(limit)}',
                            style: AppType.secondary(context)
                                .copyWith(color: _heroSoft),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.color,
    this.labelColor,
    this.valueColor,
  });
  final String label;
  final String value;

  /// Warna semantik tunggal. Diabaikan bila [valueColor] diisi.
  final Color? color;
  final Color? labelColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            label,
            style: AppType.labelMuted(context)
                .copyWith(color: labelColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: AppType.amount(context)
                .copyWith(color: valueColor ?? color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Delta pengeluaran vs bulan sebelumnya. Watch provider — bukan
/// FutureBuilder di dalam build, yang memicu query ulang tiap rebuild.
class _DeltaVsPrev extends ConsumerWidget {
  const _DeltaVsPrev({required this.month, required this.current});
  final String month;
  final int current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prev = ref.watch(_prevMonthExpenseProvider);
    return prev.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (p) {
        if (p <= 0) return const SizedBox.shrink();
        final prevKey = shiftMonth(month, -1);
        final diff = ((current - p) / p * 100).round();
        final txt = diff == 0
            ? 'Pengeluaran sama seperti ${monthLabel(prevKey)}'
            : diff > 0
                ? 'Pengeluaran naik $diff% vs ${monthLabel(prevKey)}'
                : 'Pengeluaran turun ${-diff}% vs ${monthLabel(prevKey)}';
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Text(txt,
              style: AppType.secondary(context)
                  .copyWith(color: _heroSoft)),
        );
      },
    );
  }
}

/// Strip HARI INI yang ringkas: masuk / keluar / selisih sebaris.
/// Tanggal tidak diulang (sudah di judul section + header sapaan).
class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.dayTotals});
  final AsyncValue<(int, int)> dayTotals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    return AppCard(
      child: dayTotals.when(
        loading: () => const AppSkeleton(lines: 2),
        error: (e, _) => AppErrorState(
          title: 'Ringkasan hari ini gagal dimuat.',
          onRetry: () => ref.invalidate(dayTotalsProvider),
        ),
        data: (t) {
          final net = t.$1 - t.$2;
          // Nol transaksi hari ini: satu baris jelas, bukan tiga "Rp0".
          if (t.$1 == 0 && t.$2 == 0) {
            return Text('Belum ada transaksi hari ini.',
                style: AppType.secondary(context));
          }
          return Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Masuk',
                  value: display.signed(t.$1, isExpense: false),
                  color: AppColors.incomeOf(context),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Keluar',
                  value: display.signed(t.$2, isExpense: true),
                  color: AppColors.expenseOf(context),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Selisih',
                  value: display.signed(net.abs(),
                      isExpense: net < 0),
                  color: net < 0
                      ? AppColors.expenseOf(context)
                      : AppColors.incomeOf(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Top kategori PROPORSIONAL terhadap total (bukan terhadap maksimum):
/// bar terpanjang = porsi terbesar, plus persen per baris.
/// Perhitungan & query tidak berubah — hanya presentasi.
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.byCat, required this.display});
  final AsyncValue<List<CategoryTotal>> byCat;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return byCat.when(
      loading: () => const AppSkeleton(lines: 3),
      error: (e, _) => AppErrorState(
        title: 'Kategori gagal dimuat.',
        onRetry: () =>
            ref.invalidate(monthExpenseByCategoryProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '📊',
            title: 'Belum ada pengeluaran bulan ini',
            subtitle:
                'Setiap rupiah yang dicatat bikin gambaran keuanganmu makin jelas. Yuk mulai dari satu transaksi!',
          );
        }
        final total = list.fold<int>(0, (s, e) => s + e.total);
        return Column(
          children: [
            for (final c in list.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s8),
                child: Row(
                  children: [
                    CategoryGlyph(
                        emoji: c.icon, size: 36, iconSize: 18),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                              const SizedBox(
                                  width: AppSpacing.s8),
                              Text(
                                total == 0
                                    ? '0%'
                                    : '${(100 * c.total / total).round()}%',
                                style: AppType.secondaryStrong(
                                    context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppProgress(
                            value: total == 0
                                ? 0
                                : (c.total / total)
                                    .clamp(0.0, 1.0),
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(display.money(c.total),
                        style:
                            AppType.amount(context, size: 14)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Transaksi terakhir dikelompokkan per tanggal (header tanggal +
/// baris ber-chevron). Seluruh baris tap → edit, affordance kelihatan.
class _RecentList extends ConsumerWidget {
  const _RecentList({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final display = ref.watch(displayPrefsProvider);
    return StreamBuilder<List<TxWithCategory>>(
      stream: db.watchHistory(limit: count),
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppErrorState(
            title: 'Transaksi gagal dimuat.',
          );
        }
        if (!snap.hasData) return const AppSkeleton(lines: 3);
        final list = snap.data!;
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '💸',
            title: 'Hari ini belum ada catatan',
            subtitle:
                'Belum ada transaksi — hari yang tenang juga patut dirayakan. Ketuk “Catat” saat ada pemasukan atau pengeluaran.',
          );
        }
        final groups = <DateTime, List<TxWithCategory>>{};
        for (final tx in list) {
          final d = DateTime(
              tx.date.year, tx.date.month, tx.date.day);
          (groups[d] ??= []).add(tx);
        }
        final entries = groups.entries.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : AppSpacing.s12,
                  bottom: AppSpacing.s4,
                ),
                child: Text(
                  display.date(entries[i].key),
                  style:
                      AppType.secondaryStrong(context),
                ),
              ),
              for (final tx in entries[i].value)
                TxTile(
                  tx: tx,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            TxFormScreen(existing: tx)),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
