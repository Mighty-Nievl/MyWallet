import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_card.dart';
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

/// Beranda: saldo, ringkasan hari ini, ringkasan bulan ini, top kategori,
/// transaksi terakhir.
///
/// STEP 1C — hanya UI/layout yang diubah. Logika bisnis TETAP:
/// provider, perhitungan saldo, query transaksi, navigasi bulan,
/// navigasi ke Pengaturan & form transaksi tidak disentuh.
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            96,
          ),
          children: [
            _Header(
              onOpenSettings: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            _MonthNav(
              month: month,
              onShift: (d) => ref.read(selectedMonthProvider.notifier).state =
                  shiftMonth(month, d),
            ),
            const SizedBox(height: AppSpacing.s16),
            _BalanceCard(balance: balance, totals: totals),
            if (showDaily) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              AppSection(
                title: 'Hari ini',
                child: _DailyCard(dayTotals: dayTotals),
              ),
            ],
            if (showTop) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              AppSection(
                title: 'Pengeluaran bulan ini',
                child: _CategoryList(byCat: byCat, display: display),
              ),
            ],
            if (showRecent) ...[
              const SizedBox(height: AppSpacing.sectionGap),
              AppSection(
                title: 'Terakhir dicatat',
                child: _RecentList(count: recentCount),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Judul layar + ikon aksi Pengaturan (navigasi tidak berubah).
class _Header extends StatelessWidget {
  const _Header({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('MyWallet', style: AppType.screenTitle(context)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.borderOf(context)),
          ),
          child: IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Pengaturan',
            constraints: const BoxConstraints.tightFor(
              width: 40,
              height: 40,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
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
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
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
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Saldo: kartu hero dengan background aksen utama + teks putih —
/// elemen visual terkuat di layar, jauh di atas kartu "Hari ini"
/// yang tetap putih. Label kecil, nominal besar, lalu ringkasan
/// pemasukan/pengeluaran bulan berjalan (teks putih lembut).
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance, required this.totals});
  final AsyncValue<int> balance;
  final AsyncValue<(int, int)> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Aksen utama yang adaptif: ikut pilihan user (pengaturan Tampilan)
    // maupun Material You — bukan hijau hard-code.
    final onAccent = scheme.onPrimary;
    final onAccentSoft = onAccent.withValues(alpha: 0.85);
    final divider = onAccent.withValues(alpha: 0.25);
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final showTotals = ref.watch(showMonthTotalsProvider).value ?? true;
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Saldo saat ini',
                  style: AppType.labelMuted(context)
                      .copyWith(color: onAccentSoft)),
              const Spacer(),
              InkWell(
                onTap: () => ref
                    .read(settingsServiceProvider)
                    .setHideBalance(!hide),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Icon(
                    hide ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: onAccentSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          balance.when(
            loading: () => Text('…',
                style:
                    AppType.balance(context).copyWith(color: onAccent)),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: onAccent)),
            data: (b) => Text(
              hide ? 'Rp••••••' : display.money(b),
              style:
                  AppType.balance(context).copyWith(color: onAccent),
            ),
          ),
          if (showTotals) ...[
            const SizedBox(height: AppSpacing.s16),
            Container(height: 1, color: divider),
            const SizedBox(height: AppSpacing.s12),
            totals.when(
              loading: () => Text('Memuat ringkasan…',
                  style: AppType.secondary(context)
                      .copyWith(color: onAccentSoft)),
              error: (e, _) =>
                  Text('Error: $e', style: TextStyle(color: onAccent)),
              data: (t) => Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Pemasukan',
                      value: display.signed(t.$1, isExpense: false),
                      labelColor: onAccentSoft,
                      valueColor: onAccent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: divider,
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _MiniStat(
                      label: 'Pengeluaran',
                      value: display.signed(t.$2, isExpense: true),
                      labelColor: onAccentSoft,
                      valueColor: onAccent,
                    ),
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

  /// Warna semantik tunggal (mode lama: Pemasukan=primary,
  /// Pengeluaran=error). Diabaikan bila [valueColor] diisi.
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
                .copyWith(color: labelColor)),
        const SizedBox(height: 2),
        Text(value,
            style: AppType.amount(context)
                .copyWith(color: valueColor ?? color)),
      ],
    );
  }
}

/// Ringkasan HARI INI: masuk / keluar / selisih.
/// Ikut privacy scope 'all' (nominal jadi Rp••••) + nominal ringkas.
class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.dayTotals});
  final AsyncValue<(int, int)> dayTotals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final display = ref.watch(displayPrefsProvider);
    return AppCard(
      child: dayTotals.when(
        loading: () => const _Skeleton(lines: 2),
        error: (e, _) => Text('Gagal memuat: $e'),
        data: (t) {
          final net = t.$1 - t.$2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatDate(DateTime.now()),
                  style: AppType.secondary(context)),
              const SizedBox(height: AppSpacing.s8),
              Row(
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
                  Expanded(
                    child: _MiniStat(
                      label: 'Selisih',
                      value: display.signed(net.abs(),
                          isExpense: net < 0),
                      color:
                          net < 0 ? scheme.error : scheme.primary,
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

/// Daftar top kategori bulan ini: glyph aksen, nama lebih besar,
/// progress dengan track abu terang (batas 100% kelihatan), nominal.
/// Perhitungan & query tidak berubah — hanya presentasi.
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.byCat, required this.display});
  final AsyncValue<List<CategoryTotal>> byCat;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return byCat.when(
      loading: () => const _Skeleton(lines: 3),
      error: (e, _) => Text('Gagal memuat: $e'),
      data: (list) {
        if (list.isEmpty) {
          return AppCard(
            child: Text('Belum ada pengeluaran bulan ini.',
                style: AppType.secondary(context)),
          );
        }
        final max = list.first.total;
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          AppProgress(
                            value: max == 0
                                ? 0
                                : (c.total / max).clamp(0.0, 1.0),
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(display.money(c.total),
                        style: AppType.amount(context, size: 14)),
                  ],
                ),
              ),
          ],
        );
      },
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
          return AppCard(
            child: Text(
              'Belum ada transaksi. Ketuk tombol "Catat" untuk mulai.',
              style: AppType.secondary(context),
            ),
          );
        }
        // Tanpa kartu pembungkus — TxTile tampil sebagai baris bersih.
        return Column(
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
    return AppCard(
      child: Column(
        children: List.generate(
          lines,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
