import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/b2c_chip.dart';
import '../components/category_glyph.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
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
    final month = ref.watch(selectedMonthProvider);
    // v1.30: label dompet per-baris hanya bermakna bila >1 dompet
    // (1 dompet = semua baris miliknya; suffix cuma noise + merusak
    // exact-match meta lama. Selaras _RecentList Beranda).
    final multiWallet = (ref.watch(accountsProvider).value?.length ?? 0) > 1;

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
                // v1.26: dibuka via push dari grid Beranda (bukan tab).
                onBack: Navigator.of(context).pop,
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
              child: Row(
                children: [
                  Expanded(
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
                        // v1.24.9: debounce 300ms — query + regroup +
                        // resort jalan setelah user berhenti mengetik,
                        // bukan per huruf.
                        _searchTimer?.cancel();
                        _searchTimer = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (!mounted) return;
                            final f = ref.read(historyFilterProvider);
                            ref
                                .read(historyFilterProvider.notifier)
                                .state = HistoryFilter(
                              categoryId: f.categoryId,
                              isExpense: f.isExpense,
                              keyword: v,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // v1.24.10 Opsi A: chip scroll → tombol filter +
                  // bottom-sheet (request user). Tanpa scroll horizontal,
                  // tiap dimensi punya baris sendiri yang jujur.
                  const SizedBox(width: AppSpacing.s8),
                  _FilterButton(
                    activeCount: _filterCount(
                      filter,
                      ref.watch(selectedAccountProvider),
                    ),
                    onTap: () => _openFilterSheet(context),
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
                    // v1.25: dompet spesifik ikut dihitung sebagai filter.
                    final hasFilter =
                        filter.categoryId != null ||
                        filter.isExpense != null ||
                        filter.keyword.trim().isNotEmpty ||
                        ref.watch(selectedAccountProvider) != null;
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
                        // v1.30: strip Riwayat wajib sebut dompet asal
                        // (null = Semua → tak disebut, default jujur).
                        accountLabel: _selectedAccountName(ref),
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
                          // Rapat kartu (v1.32, request user — pola sama
                          // dgn _RecentList v1.30.1): tiap baris = kartu =>
                          // butuh napas s8 antar kartu.
                          Padding(
                            padding: EdgeInsets.only(
                              top: tx == entries[i].value.first
                                  ? 0
                                  : AppSpacing.s8,
                            ),
                            child: TxTile(
                              tx: tx,
                              showDate: false,
                              // v1.24.9: arsip rapat (kritik L2).
                              dense: true,
                              // v1.30: label dompet (filter Semua + >1 dompet
                              // = tiap baris sebut asalnya).
                              showAccount: multiWallet,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      TxFormScreen(existing: tx),
                                ),
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

  /// Jumlah dimensi filter aktif (tipe + kategori + dompet).
  /// Keyword TIDAK dihitung — ia punya tombol clear sendiri di search.
  /// [selectedAccount]: null = Semua (tak dihitung). Dioper dari build
  /// (watch reaktif) — v1.25.
  int _filterCount(HistoryFilter f, int? selectedAccount) =>
      (f.isExpense != null ? 1 : 0) +
      (f.categoryId != null ? 1 : 0) +
      (selectedAccount != null ? 1 : 0);

  /// Nama dompet filter aktif (v1.30 — label dompet di strip Riwayat).
  /// null = Semua / tak ketemu / cuma 1 dompet → strip tak sebut dompet
  /// (default jujur; 1 dompet = suffix cuma noise, cermin Beranda).
  String? _selectedAccountName(WidgetRef ref) {
    final id = ref.watch(selectedAccountProvider);
    final accs = ref.watch(accountsProvider).value ?? const <Account>[];
    if (id == null || accs.length <= 1) return null;
    for (final a in accs) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  /// Opsi A (v1.24.10): buka bottom-sheet filter. Reset = nol-kan SEMUA
  /// dimensi termasuk keyword (+ teks search ikut dibersihkan) dan
  /// dompet (kembali ke Semua) — v1.25.
  Future<void> _openFilterSheet(BuildContext context) async {
    // Bahasa showModalBottomSheet form catat: drag-handle, tanpa
    // isScrollControlled (sheet secukupnya, CTA selalu terlihat).
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _FilterSheet(),
    );
    if (result?.resetAll == true && mounted) {
      _searchCtrl.clear();
      ref.read(historyFilterProvider.notifier).state = const HistoryFilter();
      ref.read(selectedAccountProvider.notifier).state = null;
    }
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

/// Tombol filter Opsi A (v1.24.10, request user): ganti chip scroll
/// horizontal. Badge angka = jumlah dimensi filter aktif (tipe +
/// kategori; keyword TIDAK dihitung — ia punya tombol clear sendiri
/// di search field). Nol aktif = ikon polos tanpa badge.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeCount > 0;
    return Semantics(
      button: true,
      label: active
          ? 'Filter aktif $activeCount, ketuk untuk ubah'
          : 'Filter, ketuk untuk ubah',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchMin,
            minWidth: AppSpacing.touchMin,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 20,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              if (active) ...[
                const SizedBox(width: AppSpacing.s4),
                Text(
                  '$activeCount',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet filter Riwayat (Opsi A): dua seksi jujur — Tipe +
/// Kategori — plus Reset. Bahasa _SheetRow form catat (glyph + nama +
/// check), bukan chip scroll. Keyword TIDAK di sini (milik search).
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final cats = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);
    return SafeArea(
      // v1.24.10: SingleChildScrollView + Column, BUKAN ListView —
      // ListView me-lazy-build anak di bawah lipatan sehingga CTA
      // "Terapkan filter" tak ada di tree sebelum scroll (test merah
      // "Found 0 widgets"). Column = semua eager + tetap scroll.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s8,
          AppSpacing.page,
          AppSpacing.sectionGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter riwayat',
                    style: AppType.sectionTitle(context),
                  ),
                ),
                // Reset jujur: nol-kan SEMUA dimensi termasuk keyword
                // (sekaligus bersihkan teks search via pop-result).
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, const _SheetResult(resetAll: true));
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('Tipe', style: AppType.secondaryStrong(context)),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: B2CFilterChip(
                    label: 'Semua',
                    selected: filter.isExpense == null,
                    onTap: () => _setType(ref, filter, null),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: B2CFilterChip(
                    label: 'Masuk',
                    selected: filter.isExpense == false,
                    // Toggle-off konsisten chip lama (kritik L1 v1.24.9).
                    onTap: () => _setType(
                      ref,
                      filter,
                      filter.isExpense == false ? null : false,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: B2CFilterChip(
                    label: 'Keluar',
                    selected: filter.isExpense == true,
                    onTap: () => _setType(
                      ref,
                      filter,
                      filter.isExpense == true ? null : true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text('Dompet', style: AppType.secondaryStrong(context)),
            const SizedBox(height: AppSpacing.s4),
            accounts.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: _SheetLoading(),
              ),
              error: (e, s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Text(
                  'Dompet gagal dimuat.',
                  style: AppType.secondary(context),
                ),
              ),
              data: (list) {
                if (list.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s12,
                    ),
                    child: Text(
                      'Satu dompet — tambah di Beranda › Kelola.',
                      style: AppType.secondary(context),
                    ),
                  );
                }
                return Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    B2CFilterChip(
                      label: 'Semua',
                      selected: selectedAccount == null,
                      onTap: () => _setAccount(ref, null),
                    ),
                    for (final a in list)
                      B2CFilterChip(
                        label: a.name,
                        selected: selectedAccount == a.id,
                        onTap: () => _setAccount(
                          ref,
                          selectedAccount == a.id ? null : a.id,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            Text('Kategori', style: AppType.secondaryStrong(context)),
            const SizedBox(height: AppSpacing.s4),
            cats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: _SheetLoading(),
              ),
              error: (e, s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Text(
                  'Kategori gagal dimuat.',
                  style: AppType.secondary(context),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s12,
                    ),
                    child: Text(
                      'Belum ada kategori.',
                      style: AppType.secondary(context),
                    ),
                  );
                }
                return Column(
                  children: [
                    _SheetCatRow(
                      icon: '📦',
                      name: 'Semua kategori',
                      selected: filter.categoryId == null,
                      onTap: () => _setCat(ref, filter, null),
                    ),
                    for (final c in list)
                      _SheetCatRow(
                        icon: c.icon,
                        name: c.name,
                        selected: filter.categoryId == c.id,
                        // Toggle-off konsisten chip lama.
                        onTap: () => _setCat(
                          ref,
                          filter,
                          filter.categoryId == c.id ? null : c.id,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            // CTA jujur: kriteria siap, user tinggal tutup (bukan angka
            // klaim — count ikut bulan+keyword, bukan milik sheet).
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, const _SheetResult(resetAll: false));
                },
                child: const Text('Terapkan filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setType(WidgetRef ref, HistoryFilter base, bool? type) {
    HapticFeedback.selectionClick();
    ref.read(historyFilterProvider.notifier).state = HistoryFilter(
      categoryId: base.categoryId,
      isExpense: type,
      keyword: base.keyword,
    );
  }

  void _setCat(WidgetRef ref, HistoryFilter base, int? id) {
    HapticFeedback.selectionClick();
    ref.read(historyFilterProvider.notifier).state = HistoryFilter(
      categoryId: id,
      isExpense: base.isExpense,
      keyword: base.keyword,
    );
  }

  void _setAccount(WidgetRef ref, int? id) {
    HapticFeedback.selectionClick();
    ref.read(selectedAccountProvider.notifier).state = id;
  }
}

/// Hasil pop sheet: resetAll = nol-kan keyword juga (+ search text).
class _SheetResult {
  const _SheetResult({required this.resetAll});
  final bool resetAll;
}

/// Baris kategori sheet — bahasa _SheetRow form catat.
class _SheetCatRow extends StatelessWidget {
  const _SheetCatRow({
    required this.icon,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String icon;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          children: [
            CategoryGlyph(emoji: icon, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Loading sheet: skeleton garis ganda (bukan shrink — anti shift).
class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) {
    return const AppCard(child: AppSkeleton(lines: 3));
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
    this.accountLabel,
  });

  /// Baris yang tampil (≤ limit query).
  final int shown;

  /// Total hasil filter tanpa limit (null = masih loading → tampil biasa).
  final int? total;
  final int inTotal;
  final int outTotal;

  /// Nama dompet filter aktif (v1.30 — label dompet di Riwayat).
  /// null = Semua (tak disebut — gabungan memang default jujur).
  final String? accountLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    // v1.24.9: jujur soal limit (kritik L4 — dulu "100 transaksi"
    // padahal datanya 150). total null = tampil biasa tanpa embel-embel.
    final head = (total != null && total! > shown)
        ? 'Menampilkan $shown dari $total transaksi · '
        : '$shown transaksi · ';
    // v1.30: scope dompet di depan (paling penting: angka milik siapa).
    final scope = accountLabel == null ? '' : 'Dompet $accountLabel · ';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Text(
        '$scope$head'
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
