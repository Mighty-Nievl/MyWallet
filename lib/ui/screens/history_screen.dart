import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/b2c_chip.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
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
  // v1.24.9: debounce ketikan (kritik L1 — dulu re-query + regroup +
  // resort per huruf). Timer UI biasa, bukan animasi (aturan no-Timer
  // hanya untuk Stagger).
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final display = ref.watch(displayPrefsProvider);
    final history = ref.watch(historyProvider);
    // v1.24.9: total jujur tanpa limit (strip "Menampilkan 100 dari N").
    final totalAsync = ref.watch(historyCountProvider);
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
              child: AppHeader(
                title: 'Riwayat',
                actionIcon: Icons.calendar_month_outlined,
                actionTooltip: 'Pilih bulan',
                onAction: () => _pickMonth(context, month),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            AppMonthNav(
              month: month,
              onShift: (d) => ref.read(selectedMonthProvider.notifier).state =
                  shiftMonth(month, d),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  // v1.24.9: hint jujur scope (kritik L4 — dulu
                  // "Cari transaksi..." padahal cuma bulan aktif).
                  hintText: 'Cari di ${monthLabel(month)}...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: filter.keyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(historyFilterProvider.notifier)
                                .state = HistoryFilter(
                              categoryId: filter.categoryId,
                              isExpense: filter.isExpense,
                            );
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (v) {
                  // v1.24.9: debounce 300ms — query + regroup + resort
                  // jalan setelah user berhenti mengetik, bukan per huruf.
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final f = ref.read(historyFilterProvider);
                    ref
                        .read(historyFilterProvider.notifier)
                        .state = HistoryFilter(
                      categoryId: f.categoryId,
                      isExpense: f.isExpense,
                      keyword: v,
                    );
                  });
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    // v1.24.9: selected buta keyword ditutup (kritik L4 —
                    // dulu keyword aktif tapi Semua tetap menyala).
                    selected:
                        filter.isExpense == null &&
                        filter.categoryId == null &&
                        filter.keyword.trim().isEmpty,
                    // v1.24.8: "Semua" beneran semua — reset kategori juga
                    // (kritik brutal L4: dulu categoryId dipertahankan,
                    // label klaim semua padahal daftar tersaring).
                    onTap: () =>
                        ref.read(historyFilterProvider.notifier).state =
                            HistoryFilter(keyword: filter.keyword),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  _FilterChip(
                    label: 'Pemasukan',
                    selected: filter.isExpense == false,
                    // v1.24.9: toggle-off konsisten dgn chip kategori
                    // (kritik L1 — dulu tipe terkunci, kategori bisa lepas).
                    onTap: () => _setFilter(
                      filter,
                      filter.isExpense == false ? null : false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  _FilterChip(
                    label: 'Pengeluaran',
                    selected: filter.isExpense == true,
                    onTap: () => _setFilter(
                      filter,
                      filter.isExpense == true ? null : true,
                    ),
                  ),
                  cats.when(
                    // v1.24.9: skeleton selebar chip, bukan shrink
                    // (kritik L1 — dulu baris melebar 1 frame saat datang).
                    loading: () => const Row(
                      children: [
                        SizedBox(width: AppSpacing.s8),
                        _ChipSkeleton(),
                        SizedBox(width: AppSpacing.s8),
                        _ChipSkeleton(),
                      ],
                    ),
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
                              final cur = ref.read(historyFilterProvider);
                              ref
                                  .read(historyFilterProvider.notifier)
                                  .state = HistoryFilter(
                                categoryId: cur.categoryId == c.id
                                    ? null
                                    : c.id,
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
                  child: AppErrorState(
                    title: 'Riwayat gagal dimuat.',
                    onRetry: () => ref.invalidate(historyProvider),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    // v1.24.9: empty bercabang (kritik L4 — dulu satu state
                    // menuduh veteran "catat transaksi pertamamu").
                    final hasFilter =
                        filter.categoryId != null ||
                        filter.isExpense != null ||
                        filter.keyword.trim().isNotEmpty;
                    return _EmptyState(
                      hasFilter: hasFilter,
                      monthLabel: monthLabel(month),
                    );
                  }
                  // v1.24.8: strip hasil (kritik brutal L3 — Riwayat tanpa
                  // total = arsip bisu). Pola _DailyStrip Beranda: satu
                  // baris count + masuk + keluar hasil filter aktif.
                  final inTotal = list
                      .where((t) => !t.isExpense)
                      .fold<int>(0, (s, t) => s + t.amount);
                  final outTotal = list
                      .where((t) => t.isExpense)
                      .fold<int>(0, (s, t) => s + t.amount);
                  // v1.24.8: grup tanggal ala Beranda (kritik brutal L1 —
                  // flat 50 baris tanpa jangkar). Sort DESC eksplisit,
                  // showDate false (tanggal ikut header grup).
                  final groups = <DateTime, List<TxWithCategory>>{};
                  for (final tx in list) {
                    final d = DateTime(
                      tx.date.year,
                      tx.date.month,
                      tx.date.day,
                    );
                    (groups[d] ??= []).add(tx);
                  }
                  final entries = groups.entries.toList()
                    ..sort((a, b) => b.key.compareTo(a.key));
                  return ListView(
                    // v1.24.4: literal 16/8 → token (kritik brutal L2).
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      AppSpacing.bottomPad,
                    ),
                    children: [
                      _ResultStrip(
                        shown: list.length,
                        // v1.24.9: total tanpa limit — null selagi loading,
                        // strip tampil biasa dulu lalu jujur saat datang.
                        total: totalAsync.value,
                        inTotal: inTotal,
                        outTotal: outTotal,
                      ),
                      for (var i = 0; i < entries.length; i++) ...[
                        Padding(
                          padding: EdgeInsets.only(
                            top: i == 0 ? 0 : AppSpacing.s12,
                            bottom: AppSpacing.s4,
                          ),
                          child: Text(
                            display.date(entries[i].key),
                            style: AppType.sectionTitle(
                              context,
                            ).copyWith(fontSize: 14),
                          ),
                        ),
                        for (final tx in entries[i].value)
                          TxTile(
                            tx: tx,
                            showDate: false,
                            // v1.24.9: arsip rapat (kritik L2).
                            dense: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => TxFormScreen(existing: tx),
                              ),
                            ),
                          ),
                      ],
                    ],
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        int.parse(current.split('-')[0]),
        int.parse(current.split('-')[1]),
      ),
      firstDate: DateTime(2020),
      // v1.24.8: kunci ke bulan berjalan (kritik brutal L1 — dulu
      // now+365 hari = pintu ke bulan kosong masa depan).
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.day,
      // v1.24.8: jujur — yang dipakai bulannya, bukan tanggalnya
      // (kritik brutal L1: mode hari untuk tugas pilih bulan).
      helpText: 'Pilih bulan (tanggal diabaikan)',
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = monthKey(picked);
    }
  }
}

/// Judul layar Riwayat sudah via [AppHeader] shared.
/// Kalender aksi langsung jadi bagian header (tanpa _Header lokal).

/// Chip filter B2C (v1.20): lihat [B2CFilterChip] — pil semibold +
/// haptic + scale-down. Radius pil penuh (bukan md 12).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return B2CFilterChip(label: label, selected: selected, onTap: onTap);
  }
}

/// Skeleton selebar chip (reserve space selagi kategori loading).
class _ChipSkeleton extends StatelessWidget {
  const _ChipSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s8,
        AppSpacing.page,
        AppSpacing.bottomPad,
      ),
      children: const [AppCard(child: AppSkeleton(lines: 3))],
    );
  }
}

/// Skeleton shimmer shared sudah di [AppSkeleton] (app_feedback.dart).

/// Strip hasil filter Riwayat: count + masuk + keluar, satu baris.
/// Bahasa yang sama dengan _DailyStrip Beranda (tanpa label tanggal —
/// tanggal ikut header grup di bawahnya).
class _ResultStrip extends ConsumerWidget {
  const _ResultStrip({
    required this.shown,
    required this.total,
    required this.inTotal,
    required this.outTotal,
  });

  /// Baris yang tampil (≤ limit query).
  final int shown;

  /// Total hasil filter tanpa limit (null = masih loading → tampil biasa).
  final int? total;
  final int inTotal;
  final int outTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    // v1.24.9: jujur soal limit (kritik L4 — dulu "100 transaksi"
    // padahal datanya 150). total null = tampil biasa tanpa embel-embel.
    final head = (total != null && total! > shown)
        ? 'Menampilkan $shown dari $total transaksi · '
        : '$shown transaksi · ';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Text(
        '$head'
        'Masuk ${display.signed(inTotal, isExpense: false)} · '
        'Keluar ${display.signed(outTotal, isExpense: true)}',
        style: AppType.secondary(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter, required this.monthLabel});

  /// true = filter aktif (bukan bulan kosong) → microcopy beda.
  final bool hasFilter;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    // v1.24.9: dua sebab, dua bahasa (kritik L4 — dulu satu state
    // menuduh veteran "catat transaksi pertamamu").
    return AppEmptyState(
      icon: '🧾',
      title: hasFilter ? 'Tidak ada yang cocok' : 'Belum ada transaksi',
      subtitle: hasFilter
          ? 'Coba longgarkan filter atau kata kunci di atas.'
          : 'Belum ada catatan di $monthLabel. Ketuk + untuk mencatat yang pertama.',
    );
  }
}
