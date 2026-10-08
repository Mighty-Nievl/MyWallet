import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../amount_input.dart';
import '../components/app_card.dart';
import '../components/category_glyph.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../format.dart';

/// Form tambah / edit transaksi.
///
/// STEP 2 — hanya UI/presentasi yang diubah. Logika TETAP:
/// tambah/edit/hapus, pilih tipe, nominal + formatter + parsing,
/// kategori + tambah kategori, tanggal, catatan, simpan + validasi,
/// dialog konfirmasi hapus, provider/action, navigasi.
class TxFormScreen extends ConsumerStatefulWidget {
  const TxFormScreen({super.key, this.existing});

  final TxWithCategory? existing;

  @override
  ConsumerState<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends ConsumerState<TxFormScreen> {
  late bool _isExpense;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isExpense = e?.isExpense ?? true;
    _amountCtrl = TextEditingController(
        text: e != null ? formatAmountField(e.amount) : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _editing => widget.existing != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
            picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseRp(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nominal dulu (lebih dari 0).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await updateTransaction(
          ref,
          id: widget.existing!.id,
          amount: amount,
          isExpense: _isExpense,
          categoryId: _categoryId,
          date: _date,
          note: _noteCtrl.text,
        );
      } else {
        await addTransaction(
          ref,
          amount: amount,
          isExpense: _isExpense,
          categoryId: _categoryId,
          date: _date,
          note: _noteCtrl.text,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await deleteTransaction(ref, widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(
        _isExpense ? expenseCategoriesProvider : incomeCategoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            AppSpacing.s32,
          ),
          children: [
            _Header(
              editing: _editing,
              onDelete: _editing ? _delete : null,
            ),
            const SizedBox(height: AppSpacing.s16),
            _TypeSelector(
              isExpense: _isExpense,
              onChanged: (v) => setState(() {
                _isExpense = v;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Text('Nominal', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            _AmountField(controller: _amountCtrl, autofocus: !_editing),
            // Quick add: sekali ketuk nominal langsung terisi.
            // Hanya di mode tambah — mode edit nominalnya sudah ada.
            if (!_editing) ...[
              const SizedBox(height: AppSpacing.s12),
              _QuickAdd(
                isExpense: _isExpense,
                onPick: (amount, note) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _amountCtrl.text = formatAmountField(amount);
                    if (note.isNotEmpty) _noteCtrl.text = note;
                  });
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s20),
            Text('Kategori', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            catsAsync.when(
              loading: () => const SizedBox(
                  height: 56, child: LinearProgressIndicator()),
              error: (e, _) =>
                  Text('Gagal memuat kategori: $e',
                      style: AppType.secondary(context)),
              data: (cats) => Column(
                children: [
                  _CategoryTile(
                    categoryId: _categoryId,
                    cats: cats,
                    onTap: () =>
                        _pickCategory(cats, _categoryId),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _showAddCategory(context),
                      child: const Text('+ Tambah kategori baru'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Text('Tanggal', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            _DateTile(date: _date, onTap: _pickDate),
            const SizedBox(height: AppSpacing.s20),
            Text('Catatan', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'cth. makan siang di warteg',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label:
                    Text(_editing ? 'Simpan Perubahan' : 'Simpan Transaksi'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: AppSpacing.s12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Hapus transaksi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.error,
                    side: BorderSide(
                        color: AppColors.borderOf(context)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pilih kategori via bottom sheet — daftar sama, logika sama,
  /// hanya presentasi (pengganti DropdownButtonFormField).
  /// Bottom sheet mengembalikan record (dipilih, id) agar pilihan
  /// "Tanpa kategori" (id null) bisa dibedakan dari dismiss biasa.
  Future<void> _pickCategory(List<Category> cats, int? current) async {
    final picked = await showModalBottomSheet<(bool, int?)>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SheetRow(
                icon: '📦',
                name: 'Tanpa kategori',
                selected: current == null,
                onTap: () => Navigator.pop(c, (true, null)),
              ),
              for (final cat in cats)
                _SheetRow(
                  icon: cat.icon,
                  name: cat.name,
                  selected: current == cat.id,
                  onTap: () => Navigator.pop(c, (true, cat.id)),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked.$1) {
      HapticFeedback.selectionClick();
      setState(() => _categoryId = picked.$2);
    }
  }

  Future<void> _showAddCategory(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kategori baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(
                labelText: 'Ikon emoji (opsional)',
                hintText: 'cth. 🍜',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final id = await addCategory(
        ref,
        name: nameCtrl.text,
        icon: iconCtrl.text,
        isExpense: _isExpense,
      );
      setState(() => _categoryId = id);
    }
  }
}

/// Header form: tombol kembali + judul + (mode edit) tombol hapus.
/// Navigasi tidak berubah (pop).
class _Header extends StatelessWidget {
  const _Header({required this.editing, this.onDelete});
  final bool editing;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Kembali',
            constraints:
                const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            editing ? 'Edit Transaksi' : 'Catat Transaksi',
            style: AppType.screenTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onDelete != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Theme.of(context).colorScheme.error),
              tooltip: 'Hapus',
              constraints:
                  const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

/// Pemilih tipe: Keluar / Masuk. SegmentedButton sama (fungsi tetap),
/// hanya styling diselaraskan (radius token + warna semantik subtle).
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.isExpense, required this.onChanged});
  final bool isExpense;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: true,
              label: Text('Keluar'),
              icon: Icon(Icons.arrow_upward, size: 18)),
          ButtonSegment(
              value: false,
              label: Text('Masuk'),
              icon: Icon(Icons.arrow_downward, size: 18)),
        ],
        selected: {isExpense},
        onSelectionChanged: (s) => onChanged(s.first),
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: AppColors.borderOf(context)),
          selectedBackgroundColor: isExpense
              ? scheme.errorContainer
              : scheme.primaryContainer,
          selectedForegroundColor: isExpense
              ? scheme.onErrorContainer
              : scheme.onPrimaryContainer,
        ),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Quick add / smart chips: sekali ketuk nominal (+ catatan) terisi.
/// Preset umum harian — tidak menyentuh logika simpan/validasi.
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.isExpense, required this.onPick});
  final bool isExpense;
  final void Function(int amount, String note) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final presets = isExpense
        ? const <({int amount, String label})>[
            (amount: 10000, label: 'Jajan Rp10 rb'),
            (amount: 15000, label: 'Parkir Rp15 rb'),
            (amount: 25000, label: 'Bensin Rp25 rb'),
            (amount: 50000, label: 'Makan Rp50 rb'),
          ]
        : const <({int amount, String label})>[
            (amount: 50000, label: 'Rp50 rb'),
            (amount: 100000, label: 'Rp100 rb'),
            (amount: 500000, label: 'Rp500 rb'),
            (amount: 1000000, label: 'Rp1 jt'),
          ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in presets)
          ActionChip(
            label: Text(p.label),
            avatar: Icon(Icons.bolt_outlined,
                size: 16, color: scheme.primary),
            onPressed: () => onPick(p.amount, ''),
          ),
      ],
    );
  }
}

/// Kolom nominal besar ala finance app: "Rp" tegas di kiri,
/// angka besar menonjol. Formatter + keyboard + controller TETAP
/// (ThousandSeparatorInputFormatter, parse via parseRp di _save).
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, this.autofocus = false});
  final TextEditingController controller;

  /// `true` hanya untuk mode tambah (baru) agar keyboard langsung muncul.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Rp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              )),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              // Zero-friction: keyboard angka langsung muncul saat form
              // tambah dibuka. Mode edit tidak autofocus (nominal sudah ada).
              autofocus: autofocus,
              inputFormatters: [ThousandSeparatorInputFormatter()],
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris kategori tappable: ikon subtle + nama + chevron.
/// Menggantikan DropdownButtonFormField (logika pilih sama).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.categoryId, required this.cats, required this.onTap});
  final int? categoryId;
  final List<Category> cats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Category? current;
    for (final c in cats) {
      if (c.id == categoryId) current = c;
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CategoryGlyph(emoji: current?.icon ?? '📦', size: 40),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  current?.name ?? 'Tanpa kategori',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.mutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris tanggal tappable — bahasa yang sama dengan _CategoryTile.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CategoryGlyph(emoji: '📅', size: 40, iconSize: 18),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDateTime(date),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    Text('Tanggal transaksi',
                        style: AppType.secondary(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.mutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris di bottom sheet kategori.
class _SheetRow extends StatelessWidget {
  const _SheetRow(
      {required this.icon,
      required this.name,
      required this.selected,
      required this.onTap});
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CategoryGlyph(emoji: icon, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            if (selected)
              Icon(Icons.check, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
