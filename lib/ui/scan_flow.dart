import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/actions.dart';
import '../data/providers.dart';
import '../data/receipt_parse.dart';
import '../data/receipt_scan_service.dart';
import 'amount_input.dart';
import 'components/app_feedback.dart';
import 'components/category_glyph.dart';
import 'components/setting_row.dart';
import 'design/app_colors.dart';
import 'design/app_radius.dart';
import 'design/app_spacing.dart';
import 'design/app_typography.dart';
import 'format.dart';

/// Alur Scan Struk v1.26 (satu pintu, dua pemanggil: tab Scan bawah +
/// item grid Beranda).
///
/// Urutan: guard platform → sheet kamera/galeri → OCR on-device →
/// [ScanPreviewScreen] (koreksi → simpan ke dompet aktif).
///
/// Mesin dipakai ulang 1:1 dari form catat (service + parser + aturan
/// prefill), jadi perilaku scan identik di semua pintu. Deviasi spec:
/// pratinjau menampilkan TEKS MENTAH OCR (expandable), bukan thumbnail
/// foto — `scanFrom` tak mengembalikan path, dan teks mentah lebih
/// berguna untuk koreksi salah-baca.
Future<void> runScanFlow(BuildContext context, WidgetRef ref) async {
  if (!ReceiptScanService.isScanSupported) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Belum didukung'),
        content: const Text(
          'Scan struk hanya tersedia di HP Android/iOS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
    return;
  }
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              0,
            ),
            child: Text(
              'Scan struk',
              style: AppType.sectionTitle(c),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Foto struk (kamera)'),
            subtitle: const Text('100% di HP, tanpa internet'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            subtitle: const Text('Pakai foto struk yang tersimpan'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return; // user batal
  // Loading jujur selama OCR (bisa 1-3 detik di HP kentang).
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  ReceiptScanResult? result;
  Object? error;
  try {
    result = await ReceiptScanService.scanFrom(source);
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  Navigator.pop(context); // tutup loading
  if (!context.mounted) return;
  if (result == null) {
    // Batal pilih foto = diam; error = snackbar jujur (aturan form catat).
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ReceiptScanEmpty || error is ReceiptScanUnsupported
                ? error.toString()
                : 'Scan gagal — coba lagi atau isi manual.',
          ),
        ),
      );
    }
    return;
  }
  HapticFeedback.selectionClick();
  final pushed = result;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ScanPreviewScreen(
        draft: pushed.draft,
        rawText: pushed.rawText,
      ),
    ),
  );
}

/// Pratinjau hasil scan: tebakan terisi di form + banner jujur +
/// teks mentah expandable. Simpan → dompet aktif (aturan form catat).
class ScanPreviewScreen extends ConsumerStatefulWidget {
  const ScanPreviewScreen({
    super.key,
    required this.draft,
    required this.rawText,
  });

  final ReceiptDraft draft;
  final String rawText;

  @override
  ConsumerState<ScanPreviewScreen> createState() =>
      _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends ConsumerState<ScanPreviewScreen> {
  late bool _isExpense;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Struk belanja = keluar, kecuali saran kategori ternyata pemasukan
    // (ditentukan ulang setelah cocokkan nama di bawah via _resolveCat —
    // default aman = keluar).
    _isExpense = true;
    final d = widget.draft;
    _amountCtrl = TextEditingController(
      text: d.amount != null ? formatAmountField(d.amount!) : '',
    );
    _noteCtrl = TextEditingController(
      text: d.note ?? d.merchant ?? '',
    );
    final dd = d.date;
    final now = DateTime.now();
    _date = dd != null
        ? DateTime(dd.year, dd.month, dd.day, now.hour, now.minute)
        : now;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Cocokkan saran nama kategori → id DB (aturan form catat 1:1).
  /// Dipanggil sekali setelah frame pertama (butuh ref.read async).
  Future<void> _resolveCategory() async {
    final name = widget.draft.suggestedCategory;
    if (name == null) return;
    final db = ref.read(dbProvider);
    final cat = await (db.select(db.categories)
          ..where((c) => c.name.equals(name))
          ..where((c) => c.deletedAt.isNull()))
        .getSingleOrNull();
    if (!mounted || cat == null) return;
    setState(() {
      _isExpense = cat.isExpense;
      _categoryId = cat.id;
    });
  }

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

  Future<void> _pickCategory() async {
    final cats = await ref.read(
      (_isExpense ? expenseCategoriesProvider : incomeCategoriesProvider)
          .future,
    );
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  0,
                ),
                child: Text(
                  'Pilih kategori',
                  style: AppType.sectionTitle(c),
                ),
              ),
              for (final cat in cats)
                ListTile(
                  leading: CategoryGlyph(
                    emoji: cat.icon,
                    size: 40,
                    iconSize: 18,
                  ),
                  title: Text(cat.name),
                  trailing: cat.id == _categoryId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(c, cat.id),
                ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _categoryId = picked);
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
      final acct = await defaultAccountId(
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
    // Toast di caller (Beranda) — context preview sudah pop.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Resolve kategori sekali (guard via _categoryId + post-frame).
    if (_categoryId == null && widget.draft.suggestedCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryId == null) _resolveCategory();
      });
    }
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
            BackHeader(
              title: 'Hasil scan',
              actions: [
                AppIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Buang',
                  color: scheme.error,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            // Banner jujur: ini tebakan OCR, bukan fakta.
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Hasil tebakan — periksa dulu sebelum simpan.',
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
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
                selected: {_isExpense},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isExpense = s.first;
                    _categoryId = null;
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Text('Nominal', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorInputFormatter()],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Text('Kategori', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            catsAsync.when(
              loading: () => const AppSkeleton(lines: 1),
              error: (_, _) => const Text('Gagal memuat kategori.'),
              data: (cats) {
                final sel = cats
                    .where((c) => c.id == _categoryId)
                    .firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CategoryGlyph(
                    emoji: sel?.icon ?? '🏷️',
                    size: 40,
                    iconSize: 18,
                  ),
                  title: Text(sel?.name ?? 'Tanpa kategori'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickCategory,
                );
              },
            ),
            const SizedBox(height: AppSpacing.s20),
            Text('Tanggal', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CategoryGlyph(
                emoji: '📅',
                size: 40,
                iconSize: 18,
              ),
              title: Text(formatDateLong(_date)),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.s20),
            Text('Catatan', style: AppType.labelMuted(context)),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'cth. Belanja Indomaret',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            ExpansionTile(
              title: const Text('Lihat teks struk'),
              subtitle: const Text('Bandingkan bila ada yang janggal'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.borderOf(context),
                    ),
                  ),
                  child: Text(
                    widget.rawText.isEmpty
                        ? '(teks kosong)'
                        : widget.rawText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),
            SizedBox(
              height: AppSpacing.ctaHeight,
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                ),
                child: Text(
                  _saving ? 'Menyimpan…' : 'Simpan',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
