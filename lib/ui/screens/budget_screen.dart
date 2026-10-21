import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../amount_input.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_month_nav.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../components/mesh_gradient.dart';
import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../widgets/account_picker.dart';
import 'categories_screen.dart';

/// Satu baris budget: data + nama/ikon + terpakai.
/// Sama dengan bentuk yang dikembalikan [budgetsProvider].
typedef BudgetEntry = ({Budget budget, String name, String icon, int spent});

/// Ambang peringatan: >= 80% dari batas = waspada (tertiary).
/// Ditulis sekali di sini — dipakai overview + item.
const _warnAt = 0.8;

/// Layar budget bulanan per kategori.
///
/// P0+P1 UI/UX (logika & data TETAP):
/// - item bisa di-tap → dialog edit beneran (prefill, kategori dikunci)
/// - hapus selalu konfirmasi + SnackBar undo 5 detik
/// - validasi inline di dialog (bukan SnackBar di belakang dialog)
/// - tombol tambah satu gaya + aksi cepat di header
/// - kategori dipilih via bottom sheet (mode tambah) ala TxForm
/// - overview menjawab "aman nggak" + label bulan dinamis
/// - aman = muted, hanya warning/over yang berwarna
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final budgets = ref.watch(budgetsProvider);

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
                title: 'Budget',
                actionIcon: Icons.add,
                actionTooltip: 'Tambah budget',
                onAction: () =>
                    _openBudgetDialog(context, ref, month, budgets.value ?? []),
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
            // v1.36.1: Budget sengaja TIDAK ikut switcher periode (limit
            // selalu per bulan) — beri tahu eksplisit agar tidak terlihat
            // seperti bug saat periode lain aktif di layar lain.
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Budget selalu dihitung per bulan. Batas berlaku untuk semua '
              'dompet; angka terpakai mengikuti dompet yang dipilih.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.mutedOf(context)),
            ),
            // v1.25: filter dompet global (tanpa Kelola — milik Beranda).
            const SizedBox(height: AppSpacing.s8),
            const AccountPicker(),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: budgets.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: AppCard(child: AppSkeleton(lines: 3)),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: AppErrorState(
                      title: 'Budget gagal dimuat.',
                      onRetry: () => ref.invalidate(budgetsProvider),
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return AppEmptyState(
                      icon: '💰',
                      title: 'Belum ada budget',
                      subtitle: 'Belum ada budget bulan ini.\nTambahkan batas per kategori agar pengeluaran terkontrol.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            _openBudgetDialog(context, ref, month, list),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah budget'),
                        // v1.30: bentuk ikut tema global (pill).
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      AppSpacing.bottomPad,
                    ),
                    children: [
                      _OverviewCard(list: list, month: month),
                      const SizedBox(height: AppSpacing.sectionGap),
                      AppSection(
                        title: 'Batas per kategori',
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              // B2C v1.20: entrance stagger per item —
                              // teks/key/logika item tidak berubah.
                              Stagger(
                                index: i.clamp(0, 6),
                                child: _BudgetItem(
                                  item: list[i],
                                  onEdit: () => _openBudgetDialog(
                                    context,
                                    ref,
                                    month,
                                    list,
                                    existing: list[i],
                                  ),
                                ),
                              ),
                              if (i < list.length - 1)
                                const Divider(height: 1, indent: 48),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openBudgetDialog(context, ref, month, list),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah budget'),
                          // v1.30: bentuk ikut tema global (pill).
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppSpacing.ctaHeight,
                            ),
                          ),
                        ),
                      ),
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

  /// Dialog tambah / ubah budget.
  ///
  /// Tambah: kategori via bottom sheet (ala TxForm), info eksplisit
  /// bila kategori sudah punya budget bulan ini (prefill + bukan
  /// timpa diam-diam). Ubah: kategori dikunci, batas prefill.
  /// Judul selalu menyebut bulan. Validasi inline. Hasil:
  /// 'saved' → SnackBar tersimpan · 'delete' → konfirmasi + hapus + undo.
  Future<void> _openBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    String month,
    List<BudgetEntry> current, {
    BudgetEntry? existing,
  }) async {
    final editing = existing != null;
    int? catId = existing?.budget.categoryId;
    final limitCtrl = TextEditingController(
      text: existing != null ? formatAmountField(existing.budget.limit) : '',
    );
    final known = {
      for (final e in current) e.budget.categoryId: e.budget.limit,
    };
    String? catError;
    String? limitError;
    bool saving = false;

    Future<void> pickCategory(
      BuildContext c,
      void Function(void Function()) setS,
    ) async {
      final cats = await ref.read(expenseCategoriesProvider.future);
      if (!c.mounted) return;
      final picked = await showModalBottomSheet<int>(
        context: c,
        builder: (s) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s12,
              AppSpacing.page,
              AppSpacing.s16,
            ),
            children: [
              Text(
                'Pilih kategori',
                style: Theme.of(s).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.s8),
              for (final cat in cats)
                InkWell(
                  onTap: () => Navigator.pop(s, cat.id),
                  borderRadius: AppRadius.mdAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        CategoryGlyph(emoji: cat.icon, size: 36, iconSize: 18),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: Theme.of(s).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (known.containsKey(cat.id))
                          Text(
                            formatRp(known[cat.id]!),
                            style: AppType.secondary(s),
                          ),
                        if (catId == cat.id)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.s8),
                            child: Icon(
                              Icons.check,
                              size: 20,
                              color: Theme.of(s).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Kelola kategori'),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(s);
                  Navigator.of(c).push(
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      setS(() {
        catId = picked;
        catError = null;
        final old = known[picked];
        if (old != null) {
          limitCtrl.text = formatAmountField(old);
          limitCtrl.selection = TextSelection.collapsed(
            offset: limitCtrl.text.length,
          );
        }
      });
    }

    try {
      final res = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setS) {
            Category? current;
            Future<void> submit() async {
              if (saving) return;
              final limit = parseRp(limitCtrl.text);
              var bad = false;
              if (!editing && catId == null) {
                catError = 'Pilih kategori dulu.';
                bad = true;
              } else {
                catError = null;
              }
              if (limit <= 0) {
                limitError = 'Isi batas lebih dari 0.';
                bad = true;
              } else {
                limitError = null;
              }
              setS(() {});
              if (bad) return;
              setS(() => saving = true);
              try {
                await upsertBudget(
                  ref,
                  categoryId: catId!,
                  limit: limit,
                  month: month,
                );
              } catch (_) {
                setS(() {
                  saving = false;
                  limitError = 'Gagal menyimpan. Coba lagi.';
                });
                return;
              }
              if (c.mounted) Navigator.pop(c, 'saved');
            }

            final overwrite =
                !editing && catId != null && known.containsKey(catId);
            return AlertDialog(
              title: Text(
                editing
                    ? 'Ubah budget · ${monthLabel(month)}'
                    : 'Tambah budget · ${monthLabel(month)}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (editing)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(c),
                          // v1.30: radius kartu ikut token (cermin box
                          // dialog utang — dalam dialog = kartu kecil).
                          borderRadius: AppRadius.cardAll,
                          border: Border.all(color: AppColors.borderOf(c)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s8,
                        ),
                        child: Row(
                          children: [
                            CategoryGlyph(emoji: existing.icon, size: 40),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    existing.name,
                                    style: Theme.of(c).textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Kategori dikunci',
                                    style: AppType.secondary(c),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FutureBuilder<List<Category>>(
                        future: ref.read(expenseCategoriesProvider.future),
                        builder: (c, snap) {
                          if (snap.hasData) {
                            for (final k in snap.data!) {
                              if (k.id == catId) {
                                current = k;
                                break;
                              }
                            }
                          }
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8,
                            ),
                            child: InkWell(
                              onTap: () => pickCategory(c, setS),
                              borderRadius: AppRadius.pillAll,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.s4,
                                ),
                                child: Row(
                                  children: [
                                    CategoryGlyph(
                                      emoji: current?.icon ?? '📦',
                                      size: 40,
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Text(
                                        current?.name ?? 'Pilih kategori',
                                        style: Theme.of(c).textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: current == null
                                                  ? AppColors.mutedOf(c)
                                                  : null,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                      color: AppColors.mutedOf(c),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    if (catError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          catError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(c).colorScheme.error,
                          ),
                        ),
                      ),
                    if (overwrite)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s8),
                        child: Text(
                          '${current?.name ?? 'Kategori ini'} sudah punya budget ${formatRp(known[catId]!)} bulan ini — Simpan akan menggantinya.',
                          style: AppType.secondary(c),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.s12),
                    TextField(
                      controller: limitCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Batas (Rp)',
                        hintText: 'cth. 1.500.000',
                        prefixText: 'Rp ',
                        errorText: limitError,
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    if (editing) ...[
                      const SizedBox(height: AppSpacing.s8),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(c, 'delete'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus budget'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(c).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(c),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: Text(saving ? 'Menyimpan…' : 'Simpan'),
                ),
              ],
            );
          },
        ),
      );
      if (res == 'saved' && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Budget tersimpan.')));
      } else if (res == 'delete' && existing != null && context.mounted) {
        await _confirmDelete(context, ref, month, existing);
      }
    } finally {
      limitCtrl.dispose();
    }
  }

  /// Konfirmasi hapus ala TxForm + SnackBar undo 5 detik.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String month,
    BudgetEntry item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus budget?'),
        content: Text(
          '${item.name} · ${monthLabel(month)} '
          '(${formatRp(item.budget.limit)}) akan dihapus. '
          'Kamu masih bisa mengurungkannya sebentar setelah ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final catId = item.budget.categoryId;
    final limit = item.budget.limit;
    await deleteBudget(ref, item.budget.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Budget ${item.name} dihapus.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () {
            upsertBudget(ref, categoryId: catId, limit: limit, month: month);
          },
        ),
      ),
    );
  }
}

/// Ringkasan bulan: label bulan dinamis + total batas + status
/// sisa/lewat + progress tebal + hitungan budget aman.
///
/// Aman = muted; hanya waspada (>=80%) & jebol yang berwarna.
class _OverviewCard extends ConsumerWidget {
  const _OverviewCard({required this.list, required this.month});
  final List<BudgetEntry> list;
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final totalLimit = list.fold<int>(0, (s, e) => s + e.budget.limit);
    final totalSpent = list.fold<int>(0, (s, e) => s + e.spent);
    final pct = totalLimit == 0
        ? 0.0
        : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final over = totalSpent > totalLimit;
    final warn = !over && pct >= _warnAt;
    final remain = totalLimit - totalSpent;
    final safe = list.where((e) => e.spent <= e.budget.limit).length;
    // Identitas v1.28: overview = MeshGradient status (aman = aksen,
    // waspada/jebol = status). Teks putih, kontras dikunci test mesh.
    final statusColor = over
        ? scheme.error
        : warn
        ? scheme.tertiary
        : scheme.primary;
    final gradBase = HSLColor.fromColor(statusColor)
        .withLightness(scheme.brightness == Brightness.dark ? 0.22 : 0.26)
        .toColor();
    Color blob(Color c, double deg) {
      final hsl = HSLColor.fromColor(c);
      final lift = scheme.brightness == Brightness.dark ? 0.08 : 0.04;
      return hsl
          .withHue(((hsl.hue + deg) % 360 + 360) % 360)
          .withLightness((hsl.lightness + lift).clamp(0.0, 1.0))
          .toColor();
    }

    final white = Colors.white;
    return MeshGradient(
      base: gradBase,
      blobs: [
        blob(statusColor, 30),
        blob(statusColor, -35),
        blob(statusColor, 60),
      ],
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anggaran · ${monthLabel(month)}',
            style: AppType.labelMuted(context)
                .copyWith(color: white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            display.money(totalLimit),
            style: AppType.balance(context).copyWith(color: white),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            over
                ? 'Lewat ${display.money(-remain)}'
                : '${display.money(remain)} tersisa',
            style: AppType.secondary(context).copyWith(
              color: white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppProgress(
            value: pct,
            color: Colors.white.withValues(alpha: 0.95),
            height: 8,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '$safe dari ${list.length} budget aman',
            style: AppType.secondary(context)
                .copyWith(color: white.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }
}

/// Satu item budget — bisa di-tap untuk ubah.
/// Nominal tegas (spent bold + limit muted), status hanya
/// berwarna saat waspada/jebol, chevron sebagai affordance tap.
class _BudgetItem extends ConsumerWidget {
  const _BudgetItem({required this.item, required this.onEdit});
  final BudgetEntry item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final b = item;
    final pct = b.budget.limit == 0
        ? 0.0
        : (b.spent / b.budget.limit).clamp(0.0, 1.0);
    final over = b.spent > b.budget.limit;
    final warn = !over && pct >= _warnAt;
    final color = over
        ? scheme.error
        : warn
        ? scheme.tertiary
        : null;
    final remain = b.budget.limit - b.spent;
    return InkWell(
      // v1.30: umpan sentuh ikut baris lain (satu sentuh = jujur bisa tap).
      onTap: () {
        HapticFeedback.selectionClick();
        onEdit();
      },
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          children: [
            CategoryGlyph(emoji: b.icon, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Row(
                    children: [
                      Text(
                        display.money(b.spent),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Flexible(
                        child: Text(
                          ' / ${display.money(b.budget.limit)}',
                          style: AppType.secondary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppProgress(value: pct, color: color ?? scheme.primary),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    over
                        ? 'Lewat ${display.money(-remain)} (${(100 * b.spent / b.budget.limit).round()}%)'
                        : '${display.money(remain)} tersisa · ${(pct * 100).round()}%',
                    style: color == null
                        ? AppType.secondary(context)
                        : AppType.secondary(
                            context,
                          ).copyWith(color: color, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.mutedOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
