import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/category_glyph.dart';
import '../components/setting_row.dart';
import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Halaman Kelola Kategori — dibuka dari Pengaturan → Kelola kategori.
///
/// STEP 4 — hanya presentasi yang diubah. Logika TETAP:
/// list, ikon, nama, tambah, hapus, validasi, dialog, provider,
/// database. Tidak ada edit kategori di versi ini (sama seperti
/// sebelumnya) — tambah + hapus saja.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: 'Kategori'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: cats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: _LoadingCard(),
                ),
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gagal memuat kategori.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Periksa lagi sebentar.',
                          style: AppType.secondary(context),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(categoriesProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return AppEmptyState(
                      icon: '📦',
                      title: 'Belum ada kategori',
                      subtitle:
                          'Tambahkan kategori agar transaksi lebih rapi.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            _showAddCategory(context, ref),
                        icon: const Icon(Icons.add),
                        label:
                            const Text('Tambah kategori'),
                        // v1.30: bentuk ikut tema global (pill).
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(48),
                        ),
                      ),
                    );
                  }
                  final expense = list
                      .where((c) => c.isExpense)
                      .toList();
                  final income = list
                      .where((c) => !c.isExpense)
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      96,
                    ),
                    children: [
                      if (expense.isNotEmpty)
                        SettingsGroup(
                          title: 'Pengeluaran',
                          children: [
                            for (var i = 0; i < expense.length; i++)
                              // B2C v1.20: entrance stagger —
                              // teks/key/logika row tidak berubah.
                              Stagger(
                                index: i.clamp(0, 6),
                                child: _CategoryRow(
                                  cat: expense[i],
                                  onDelete: () =>
                                      _confirmDeleteCat(
                                          context, ref, expense[i]),
                                ),
                              ),
                          ],
                        ),
                      if (expense.isNotEmpty &&
                          income.isNotEmpty)
                        const SizedBox(
                            height:
                                AppSpacing.sectionGap),
                      if (income.isNotEmpty)
                        SettingsGroup(
                          title: 'Pemasukan',
                          children: [
                            for (var i = 0; i < income.length; i++)
                              Stagger(
                                index: i.clamp(0, 6),
                                child: _CategoryRow(
                                  cat: income[i],
                                  onDelete: () =>
                                      _confirmDeleteCat(
                                          context, ref, income[i]),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.s16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _showAddCategory(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text(
                              'Tambah kategori'),
                          // v1.30: bentuk ikut tema global (pill).
                          style: FilledButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(AppSpacing.ctaHeight),
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

  Future<void> _showAddCategory(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    var isExpense = true;
    String? nameError;
    final ok = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Kategori baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    hintText: 'cth. Jajan',
                    errorText: nameError,
                  ),
                  onSubmitted: (_) =>
                      Navigator.pop(c, true),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: iconCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ikon emoji (opsional)',
                    hintText: 'cth. 🍔',
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('Keluar'),
                        icon: Icon(Icons.arrow_upward,
                            size: 18)),
                    ButtonSegment(
                        value: false,
                        label: Text('Masuk'),
                        icon: Icon(Icons.arrow_downward,
                            size: 18)),
                  ],
                  selected: {isExpense},
                  onSelectionChanged: (s) =>
                      setS(() => isExpense = s.first),
                  style: SegmentedButton.styleFrom(
                    // v1.30: pill ikut bahasa tombol tema (selaras form).
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillAll,
                    ),
                    side: BorderSide(
                        color:
                            AppColors.borderOf(context)),
                    selectedBackgroundColor: isExpense
                        ? Theme.of(context)
                            .colorScheme
                            .errorContainer
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                    selectedForegroundColor: isExpense
                        ? Theme.of(context)
                            .colorScheme
                            .onErrorContainer
                        : Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                  ),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setS(() => nameError =
                        'Isi nama kategori dulu.');
                    return;
                  }
                  Navigator.pop(c, true);
                },
                child: const Text('Tambah')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await addCategory(ref,
          name: nameCtrl.text,
          icon: iconCtrl.text,
          isExpense: isExpense);
    }
  }

  Future<void> _confirmDeleteCat(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${c.name}"?'),
        content: const Text(
            'Transaksi yang memakai kategori ini jadi "Tanpa kategori".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(ctx).colorScheme.error,
                foregroundColor:
                    Theme.of(ctx).colorScheme.onError,
              ),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await deleteCategory(ref, c.id);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(child: AppSkeleton(lines: 3));
  }
}

/// Satu baris kategori: ikon konsisten TxTile + nama +
/// tombol hapus 48px. Tap baris tidak melakukan apa-apa
/// (tidak ada edit) — hanya hapus via ikon.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.cat, required this.onDelete});
  final Category cat;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          CategoryGlyph(
              emoji: cat.icon, size: 36, iconSize: 18),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              cat.name,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Hapus ${cat.name}',
            color: AppColors.mutedOf(context),
            constraints: const BoxConstraints.tightFor(
                width: 48, height: 48),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
