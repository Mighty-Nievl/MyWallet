import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/receipt_parse.dart';
import '../../data/receipt_scan_service.dart';
import '../amount_input.dart';
import '../components/app_card.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../components/b2c_chip.dart';
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
  const TxFormScreen({
    super.key,
    this.existing,
    this.startAsExpense,
    this.initialAmount,
    this.initialAccountId,
  });

  final TxWithCategory? existing;

  /// Tipe awal saat dibuka dari pintasan Beranda (diabaikan saat edit).
  final bool? startAsExpense;

  /// Nominal awal (Rupiah) saat dibuka dari Catat Kilat Beranda.
  /// Diabaikan saat edit ([existing] menang) — backward-compatible:
  /// semua pemanggil lama tanpa param ini tetap jalan.
  final int? initialAmount;

  /// Dompet tujuan awal (v1.32 — request user "aksi catat belum
  /// memperlihatkan dompet mana yg akan dicatat"): kartu/detail/grid
  /// teruskan id dompetnya; null = ikut filter aktif/global.
  /// Diabaikan saat edit (dompet ikut induk, aturan v1.25).
  final int? initialAccountId;

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
  bool _scanning = false;
  // Dompet tujuan catat (v1.32): eksplisit per-buka form (bukan baca
  // filter global di _save — filter bisa berubah / null = Semua).
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isExpense = e?.isExpense ?? widget.startAsExpense ?? true;
    // Catat Kilat Beranda: form terbuka dengan nominal sudah terisi
    // (widget.initialAmount). Edit ([existing]) selalu menang.
    final seed = e != null
        ? formatAmountField(e.amount)
        : (widget.initialAmount != null && widget.initialAmount! > 0
              ? formatAmountField(widget.initialAmount!)
              : '');
    _amountCtrl = TextEditingController(text: seed);
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    // v1.36.1: tanggal baru ikut periode yang dilihat. Dulu selalu
    // DateTime.now() — mencatat saat menjelajah kemarin/bulan lalu
    // menyimpan transaksi di luar layar (seolah hilang).
    _date =
        e?.date ??
        ref.read(activePeriodProvider).suggestedTransactionDate();
    _categoryId = e?.categoryId;
    // v1.32: dompet awal = param eksplisit > filter aktif (dulu diam-diam
    // defaultAccountId di _save — user tak pernah tahu dompet mana).
    _accountId =
        widget.initialAccountId ?? ref.read(selectedAccountProvider);
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
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
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
        // v1.32: dompet = pilihan user di form (state _accountId, terlihat
        // di UI "Catat ke"). Fallback defaultAccountId bila null (mis.
        // filter Semua + belum pilih). Tanpa dompet = mustahil pasca-v4.
        final acct = _accountId ??
            await defaultAccountId(
              ref.read(dbProvider),
              ref.read(selectedAccountProvider),
            );
        if (acct == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belum ada dompet.')),
          );
          return;
        }
        await addTransaction(
          ref,
          amount: amount,
          isExpense: _isExpense,
          categoryId: _categoryId,
          date: _date,
          note: _noteCtrl.text,
          accountId: acct,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  /// Hapus transaksi (v1.38.4): tanpa dialog konfirmasi, tapi bisa
  /// diurungkan 6 detik — hapus transaksi itu soft-delete (`deletedAt`
  /// tombstone), jadi "Urungkan" cuma membersihkan tombstone-nya dan tidak
  /// ada data yang benar-benar hilang. Dialog "tidak bisa dikembalikan"
  /// justru berbohong ke user: datanya masih ada.
  Future<void> _delete() async {
    final id = widget.existing!.id;
    // Tangkap dulu: setelah `pop`, `context`/`ref` widget ini sudah mati,
    // tapi messenger & db milik Scaffold/container tetap hidup.
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    await deleteTransaction(ref, id);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaksi dihapus.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () => restoreTransaction(db, id),
        ),
      ),
    );
  }

  /// Scan struk: pilih kamera/galeri → OCR on-device (ML Kit) →
  /// prefill nominal + tanggal + catatan + saran kategori.
  /// Logika simpan TETAP (user tetap tekan Simpan manual).
  Future<void> _pickScanSource() async {
    if (_scanning) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto struk (kamera)'),
              subtitle: const Text('100% di HP, tanpa internet'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await _scanReceipt(source);
  }

  Future<void> _scanReceipt(ImageSource source) async {
    setState(() => _scanning = true);
    try {
      final result = await ReceiptScanService.scanFrom(source);
      if (!mounted) return;
      if (result == null) return; // user batal pilih foto
      await _applyDraft(result.draft);
    } on ReceiptScanEmpty catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } on ReceiptScanUnsupported catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan gagal — coba lagi atau isi manual.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Terapkan hasil OCR ke form. Hanya isi kolom yang masih kosong
  /// (kecuali nominal — selalu timpa karena itu inti scan).
  /// Kategori dicocokkan ke nama di DB agar id-nya valid.
  Future<void> _applyDraft(ReceiptDraft draft) async {
    int? catId;
    bool? catIsExpense;
    if (draft.suggestedCategory != null) {
      final db = ref.read(dbProvider);
      final cat =
          await (db.select(db.categories)
                ..where((c) => c.name.equals(draft.suggestedCategory!))
                ..where((c) => c.deletedAt.isNull()))
              .getSingleOrNull();
      if (cat != null) {
        catId = cat.id;
        catIsExpense = cat.isExpense;
      }
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (catIsExpense != null) {
        _isExpense = catIsExpense;
        _categoryId = catId;
      } else if (catId != null) {
        _categoryId = catId;
      }
      if (draft.amount != null) {
        _amountCtrl.text = formatAmountField(draft.amount!);
      }
      if (draft.date != null) {
        _date = DateTime(
          draft.date!.year,
          draft.date!.month,
          draft.date!.day,
          _date.hour,
          _date.minute,
        );
      }
      if (_noteCtrl.text.trim().isEmpty) {
        if (draft.note != null && draft.note!.isNotEmpty) {
          _noteCtrl.text = draft.note!;
        } else if (draft.merchant != null) {
          _noteCtrl.text = draft.merchant!;
        }
      }
    });
    if (!mounted) return;
    final parts = <String>[];
    if (draft.amount != null) parts.add(formatRp(draft.amount!));
    if (draft.merchant != null) parts.add(draft.merchant!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parts.isEmpty
              ? 'Struk terbaca, tapi nominal tidak ketemu — isi manual ya.'
              : 'Struk terbaca: ${parts.join(' · ')} — cek lagi ya.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(
      _isExpense ? expenseCategoriesProvider : incomeCategoriesProvider,
    );

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
            // v1.24.7: _Header privat → BackHeader shared + slot aksi
            // (satu keluarga header global, bukan 2 bahasa).
            BackHeader(
              title: _editing ? 'Edit Transaksi' : 'Catat Transaksi',
              actions: [
                if (!_editing)
                  _scanning
                      ? const SizedBox(
                          width: AppSpacing.touchMin,
                          height: AppSpacing.touchMin,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : AppIconButton(
                          icon: Icons.document_scanner_outlined,
                          tooltip: 'Scan struk',
                          onPressed: _pickScanSource,
                        ),
                if (_editing)
                  AppIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Hapus',
                    color: Theme.of(context).colorScheme.error,
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            _TypeSelector(
              isExpense: _isExpense,
              onChanged: (v) => setState(() {
                _isExpense = v;
                _categoryId = null;
              }),
            ),
            // v1.32 (request user): dompet tujuan TERLIHAT + bisa ganti
            // (dulu diam-diam ikut filter). Edit = terkunci ikut induk.
            if (!_editing) ...[
              const SizedBox(height: AppSpacing.s20),
              Text('Catat ke', style: AppType.labelMuted(context)),
              const SizedBox(height: AppSpacing.s8),
              _AccountField(
                selectedId: _accountId,
                onPick: (id) => setState(() => _accountId = id),
              ),
            ],
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
              loading: () =>
                  const SizedBox(height: 56, child: AppSkeleton(lines: 1)),
              error: (e, _) => const Text(
                'Gagal memuat kategori.',
                style: TextStyle(fontSize: 13),
              ),
              data: (cats) => Column(
                children: [
                  _CategoryTile(
                    categoryId: _categoryId,
                    cats: cats,
                    onTap: () => _pickCategory(cats, _categoryId),
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
                label: Text(_editing ? 'Simpan Perubahan' : 'Simpan Transaksi'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  // v1.30 (karakteristik #3): pill ikut tema global
                  // (dulu md override = satu-satunya CTA kotak).
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillAll,
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
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: AppColors.borderOf(context)),
                    minimumSize: const Size.fromHeight(48),
                    // v1.30 (karakteristik #3): pill ikut tema global
                    // (tombol hapus = varian destruktif, bukan kotak).
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillAll,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.sectionGap,
            ),
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
              decoration: const InputDecoration(labelText: 'Nama'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.s12),
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
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tambah'),
          ),
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
            icon: Icon(Icons.arrow_upward, size: 18),
          ),
          ButtonSegment(
            value: false,
            label: Text('Masuk'),
            icon: Icon(Icons.arrow_downward, size: 18),
          ),
        ],
        selected: {isExpense},
        onSelectionChanged: (s) {
          // B2C v1.20: haptic saat ganti tipe Keluar/Masuk.
          HapticFeedback.selectionClick();
          onChanged(s.first);
        },
        style: SegmentedButton.styleFrom(
          // v1.30 (karakteristik #3): pill ikut bahasa tombol tema
          // (M3 default = stadium; override md dulu melawan itu).
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillAll,
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
          // B2C v1.20: chip kilat pakai bahasa pil yang sama dengan
          // filter Riwayat (selalu unselected = netral, bukan aksi).
          B2CFilterChip(
            label: p.label,
            selected: false,
            onTap: () => onPick(p.amount, ''),
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
        // v1.30 (karakteristik #3): kartu input ikut token kartu
        // (dulu md = beda sendiri vs AppCard lain).
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Rp',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              // Zero-friction: keyboard angka langsung muncul saat form
              // tambah dibuka. Mode edit tidak autofocus (nominal sudah ada).
              autofocus: autofocus,
              inputFormatters: [ThousandSeparatorInputFormatter()],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
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
  const _CategoryTile({
    required this.categoryId,
    required this.cats,
    required this.onTap,
  });
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Row(
            children: [
              CategoryGlyph(emoji: current?.icon ?? '📦', size: 40),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  current?.name ?? 'Tanpa kategori',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Row(
            children: [
              CategoryGlyph(emoji: '📅', size: 40, iconSize: 18),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(date),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Tanggal transaksi',
                      style: AppType.secondary(context),
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
      ),
    );
  }
}

/// Baris dompet tappable (v1.32) — bahasa yang sama dengan _CategoryTile:
/// AppCard + glyph + nama + chevron, tap = sheet pilih dompet.
/// null = belum pilih (ikut fallback defaultAccountId di _save).
class _AccountField extends ConsumerWidget {
  const _AccountField({required this.selectedId, required this.onPick});
  final int? selectedId;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return accounts.when(
      loading: () => const SizedBox(height: 56, child: AppSkeleton(lines: 1)),
      error: (_, _) => const Text(
        'Gagal memuat dompet.',
        style: TextStyle(fontSize: 13),
      ),
      data: (list) {
        Account? current;
        for (final a in list) {
          if (a.id == selectedId) current = a;
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: InkWell(
            onTap: () async {
              final picked = await _pickAccount(context, list, selectedId);
              if (picked != null) {
                HapticFeedback.selectionClick();
                onPick(picked);
              }
            },
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                children: [
                  const CategoryGlyph(emoji: '👛', size: 40, iconSize: 18),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      current?.name ?? 'Pilih dompet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          ),
        );
      },
    );
  }

  /// Sheet pilih dompet — daftar sama, hanya presentasi (pengganti
  /// DropdownButtonFormField). Column-eager ikut sheet Riwayat (aturan
  /// v1.24.10: ListView-lazy sembunyikan ekor di bawah lipatan).
  Future<int?> _pickAccount(
    BuildContext context,
    List<Account> list,
    int? current,
  ) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in list)
                _SheetRow(
                  icon: '👛',
                  name: a.name,
                  selected: a.id == current,
                  onTap: () => Navigator.pop(ctx, a.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris di bottom sheet kategori.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
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
      // v1.30: splash baris sheet kecil ikut md (bukan kartu —
      // selaras sheet Riwayat/Budget).
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
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
