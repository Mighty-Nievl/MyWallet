import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/debt_actions.dart';
import '../../data/providers.dart';
import '../amount_input.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';

/// Layar Utang (tab ke-5) — manajer utang-piutang v1.15.
///
/// - Utang = aku pinjam (catat = pemasukan, bayar = pengeluaran).
/// - Piutang = aku meminjami (catat = pengeluaran, terima = pemasukan).
/// - Tiap aksi menulis transaksi CERMIN → saldo + laporan + riwayat
///   ikut otomatis (opsi B). Status lunas dihitung (paid >= total).
/// - Komponen reuse: AppHeader/AppCard/AppProgress/AppEmptyState/
///   AppSection/CategoryGlyph + formatter nominal + display prefs.
///
/// Pemilik TextEditingController yang hidup-mati bareng route dialog.
///
/// Perbaikan insiden 9 Okt 2026 (`TextEditingController was used after
/// being disposed`, bikin widget test merah + error laten di HP):
/// controller yang dibuat di method pembuka lalu di-dispose di `finally`
/// mati DULUAN — route dialog masih animasi keluar (±200ms) dan rebuild
/// antre (unfocus dsb.) masih menyentuhnya. Di sini controller dibuat di
/// [initState] dan dibuang di [dispose] (jalan saat route benar-benar
/// unmount), jadi tidak ada use-after-dispose. Dipakai dialog catat/ubah
/// utang + dialog bayar (pola sama).
class _DialogControllers extends StatefulWidget {
  const _DialogControllers({
    required this.count,
    required this.builder,
    this.initial = const [],
  });

  /// Jumlah controller.
  final int count;

  /// Teks awal per controller (kurang = string kosong).
  final List<String> initial;

  /// Isi dialog: controller siap pakai via [ctrls].
  final Widget Function(
    BuildContext c,
    StateSetter setS,
    List<TextEditingController> ctrls,
  ) builder;

  @override
  State<_DialogControllers> createState() => _DialogControllersState();
}

class _DialogControllersState extends State<_DialogControllers> {
  late final List<TextEditingController> _ctrls = List.generate(
    widget.count,
    (i) => TextEditingController(
      text: i < widget.initial.length ? widget.initial[i] : '',
    ),
  );

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (c, setS) => widget.builder(c, setS, _ctrls),
    );
  }
}

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);

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
                title: 'Utang',
                actionIcon: Icons.add,
                actionTooltip: 'Catat utang / piutang',
                onAction: () => _openDebtDialog(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: debts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: AppCard(child: AppSkeleton(lines: 3)),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppSpacing.s24),
                    child: AppErrorState(
                      title: 'Utang gagal dimuat.',
                      onRetry: () =>
                          ref.invalidate(debtsProvider),
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return AppEmptyState(
                      icon: '🤝',
                      title: 'Belum ada utang / piutang',
                      subtitle:
                          'Catat pinjaman ke teman atau\ntagihan yang harus dibayar.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            _openDebtDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Catat utang'),
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppRadius.md),
                          ),
                        ),
                      ),
                    );
                  }
                  final aktif =
                      list.where((e) => !e.done).toList();
                  final lunas =
                      list.where((e) => e.done).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      AppSpacing.bottomPad,
                    ),
                    children: [
                      // B2C v1.20: entrance stagger — teks/key/logika tetap.
                      Stagger(index: 0, child: _DebtOverview(list: list)),
                      if (aktif.isNotEmpty) ...[
                        const SizedBox(
                            height: AppSpacing.sectionGap),
                        AppSection(
                          title:
                              'Aktif (${aktif.length})',
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < aktif.length;
                                  i++) ...[
                                _DebtItem(
                                  entry: aktif[i],
                                  onTap: () => _openDebtDetail(
                                      context,
                                      ref,
                                      aktif[i]),
                                ),
                                if (i < aktif.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 48,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (lunas.isNotEmpty) ...[
                        const SizedBox(
                            height: AppSpacing.sectionGap),
                        AppSection(
                          title:
                              'Lunas (${lunas.length})',
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < lunas.length;
                                  i++) ...[
                                _DebtItem(
                                  entry: lunas[i],
                                  onTap: () => _openDebtDetail(
                                      context,
                                      ref,
                                      lunas[i]),
                                ),
                                if (i < lunas.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 48,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openDebtDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label:
                              const Text('Catat utang / piutang'),
                          style: FilledButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
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

  // ---------- Dialog tambah / ubah ----------

  /// Dialog catat utang baru / ubah yang ada.
  /// Tambah: tipe via SegmentedButton; Ubah: tipe dikunci.
  /// Validasi inline (bukan SnackBar di belakang dialog).
  Future<void> _openDebtDialog(
    BuildContext context,
    WidgetRef ref, {
    DebtEntry? existing,
  }) async {
    final editing = existing != null;
    var isDebt = existing?.debt.isDebt ?? true;
    // Controller dimiliki route dialog (_DialogControllers): dibuat di
    // initState + dibuang di dispose (saat unmount). JANGAN buat di sini
    // + dispose di finally — insiden 9 Okt 2026: route masih animasi
    // keluar saat finally jalan → rebuild antre menyentuh controller mati
    // (`TextEditingController was used after being disposed`).
    final initialTexts = [
      existing?.debt.name ?? '',
      existing != null ? formatAmountField(existing.debt.total) : '',
      existing?.debt.note ?? '',
    ];
    var date = existing?.debt.date ?? DateTime.now();
    var due = existing?.debt.dueDate;
    String? nameError;
    String? totalError;
    bool saving = false;

    Future<void> pickDay(
      BuildContext c,
      void Function(void Function()) setS,
      DateTime current,
      void Function(DateTime) apply,
    ) async {
      final picked = await showDatePicker(
        context: c,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      );
      if (picked != null) {
        HapticFeedback.selectionClick();
        setS(() => apply(DateTime(
            picked.year, picked.month, picked.day,
            current.hour, current.minute)));
      }
      // Batal = biarkan (hapus jatuh tempo via tombol X di _DayTile).
    }

    final res = await showDialog<String>(
      context: context,
      builder: (c) => _DialogControllers(
        count: 3,
        initial: initialTexts,
        builder: (c, setS, ctrls) {
          final nameCtrl = ctrls[0];
          final totalCtrl = ctrls[1];
          final noteCtrl = ctrls[2];
          Future<void> submit() async {
            if (saving) return;
            final total = parseRp(totalCtrl.text);
              var bad = false;
              if (nameCtrl.text.trim().isEmpty) {
                nameError = 'Isi nama dulu.';
                bad = true;
              } else {
                nameError = null;
              }
              if (total <= 0) {
                totalError = 'Isi total lebih dari 0.';
                bad = true;
              } else {
                if (editing &&
                    total < existing.paid) {
                  totalError =
                      'Minimal ${formatRp(existing.paid)} (sudah dibayar).';
                  bad = true;
                } else {
                  totalError = null;
                }
              }
              setS(() {});
              if (bad) return;
              setS(() => saving = true);
              try {
                if (editing) {
                  await editDebt(ref,
                      id: existing.debt.id,
                      name: nameCtrl.text,
                      total: total,
                      date: date,
                      dueDate: due,
                      note: noteCtrl.text);
                } else {
                  await addDebt(ref,
                      name: nameCtrl.text,
                      isDebt: isDebt,
                      total: total,
                      date: date,
                      dueDate: due,
                      note: noteCtrl.text);
                }
              } on ArgumentError catch (e) {
                setS(() {
                  saving = false;
                  totalError = e.message;
                });
                return;
              } on DebtInvalidTotalException {
                setS(() {
                  saving = false;
                  totalError =
                      'Minimal ${formatRp(existing!.paid)} (sudah dibayar).';
                });
                return;
              } catch (_) {
                setS(() {
                  saving = false;
                  totalError =
                      'Gagal menyimpan. Coba lagi.';
                });
                return;
              }
              if (c.mounted) Navigator.pop(c, 'saved');
            }

            return AlertDialog(
              title: Text(editing
                  ? 'Ubah ${existing.debt.isDebt ? 'utang' : 'piutang'}'
                  : 'Catat utang / piutang'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    if (!editing) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Utang'),
                            icon: Icon(
                                Icons.arrow_downward,
                                size: 18),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Piutang'),
                            icon: Icon(Icons.arrow_upward,
                                size: 18),
                          ),
                        ],
                        selected: {isDebt},
                        onSelectionChanged: (s) =>
                            setS(() => isDebt = s.first),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        isDebt
                            ? 'Aku pinjam → saldo BERTAMBAH, bayar = keluar.'
                            : 'Aku meminjami → saldo BERKURANG, terima = masuk.',
                        style: AppType.secondary(c),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                    ] else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(c),
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(
                              color: AppColors.borderOf(c)),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8),
                        child: Text(
                          existing.debt.isDebt
                              ? 'Utang (tipe dikunci)'
                              : 'Piutang (tipe dikunci)',
                          style: AppType.secondary(c),
                        ),
                      ),
                    if (editing)
                      const SizedBox(height: AppSpacing.s12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama orang',
                        hintText: 'cth. Budi',
                        errorText: nameError,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextField(
                      controller: totalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandSeparatorInputFormatter()
                      ],
                      decoration: InputDecoration(
                        labelText: 'Total (Rp)',
                        hintText: 'cth. 1.000.000',
                        prefixText: 'Rp ',
                        errorText: totalError,
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _DayTile(
                      label: 'Tanggal',
                      date: date,
                      onTap: () => pickDay(c, setS, date,
                          (d) => date = d),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _DayTile(
                      label: 'Jatuh tempo (opsional)',
                      date: due,
                      placeholder: 'Tanpa jatuh tempo',
                      onTap: () => pickDay(
                          c, setS, due ?? DateTime.now(),
                          (d) => due = d),
                      onClear: due == null
                          ? null
                          : () => setS(() => due = null),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        hintText: 'cth. pinjam buat bensin',
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                    ),
                    if (editing &&
                        existing.paid > 0) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Sudah dibayar ${formatRp(existing.paid)} — '
                        'total baru tidak boleh di bawah itu.',
                        style: AppType.secondary(c),
                      ),
                    ],
                    if (editing) ...[
                      const SizedBox(
                          height: AppSpacing.s8),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () =>
                                Navigator.pop(c, 'delete'),
                        icon: const Icon(
                            Icons.delete_outline,
                            size: 18),
                        label: Text(editing
                            ? 'Hapus ${existing.debt.isDebt ? 'utang' : 'piutang'}'
                            : 'Hapus'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(c)
                              .colorScheme
                              .error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(c),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: saving ? null : submit,
                    child: Text(
                        saving ? 'Menyimpan…' : 'Simpan')),
              ],
            );
        },
      ),
    );
    if (res == 'saved' && context.mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(editing
                ? 'Perubahan tersimpan.'
                : '${isDebt ? 'Utang' : 'Piutang'} tercatat — saldo ikut berubah.')),
      );
    } else if (res == 'delete' &&
        existing != null &&
        context.mounted) {
      await _confirmDelete(context, ref, existing);
    }
  }

  /// Konfirmasi hapus ala hapus transaksi (tanpa undo: cermin banyak).
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DebtEntry item,
  ) async {
    final d = item.debt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            'Hapus ${d.isDebt ? 'utang' : 'piutang'}?'),
        content: Text(
          '${d.name} · ${formatRp(d.total)} akan dihapus beserta '
          '${item.paid > 0 ? 'riwayat bayar + ' : ''}catatan transaksinya di '
          'saldo & riwayat. Tidak bisa dikembalikan.',
        ),
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
    if (ok != true || !context.mounted) return;
    await removeDebt(ref, d.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${d.isDebt ? 'Utang' : 'Piutang'} ${d.name} dihapus.')),
    );
  }

  // ---------- Detail + cicilan ----------

  /// Lembar detail: progress + info + riwayat bayar + aksi.
  Future<void> _openDebtDetail(
    BuildContext context,
    WidgetRef ref,
    DebtEntry entry,
  ) async {
    final db = ref.read(dbProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            AppSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(
                entry: entry,
                onEdit: () {
                  Navigator.pop(c);
                  _openDebtDialog(context, ref,
                      existing: entry);
                },
                onDelete: () {
                  Navigator.pop(c);
                  _confirmDelete(context, ref, entry);
                },
              ),
              const SizedBox(height: AppSpacing.s12),
              StreamBuilder<List<DebtPayment>>(
                stream:
                    watchDebtPayments(db, entry.debt.id),
                builder: (c, snap) {
                  final pays = snap.data ?? const [];
                  if (pays.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s8),
                      child: Text(
                        'Belum ada pembayaran.',
                        style: AppType.secondary(c),
                      ),
                    );
                  }
                  return Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pays.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = pays[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CategoryGlyph(
                              emoji: '🤝',
                              size: 36,
                              iconSize: 18),
                          title: Text(
                            formatRp(p.amount),
                            style: Theme.of(c)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight:
                                        FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${formatDate(p.date)}${p.note.trim().isNotEmpty ? ' · ${p.note.trim()}' : ''}',
                            style:
                                AppType.secondary(c),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                size: 20),
                            tooltip: 'Hapus pembayaran',
                            color: Theme.of(c)
                                .colorScheme
                                .error,
                            onPressed: () =>
                                _confirmDeletePayment(
                                    context, ref, p),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s12),
              if (!entry.done)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      _openPaymentDialog(
                          context, ref, entry);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(entry.debt.isDebt
                        ? 'Bayar (${formatRp(entry.remaining)} lagi)'
                        : 'Terima (${formatRp(entry.remaining)} lagi)'),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                AppRadius.md),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s12),
                  alignment: Alignment.center,
                  child: Text(
                    'Lunas — tidak ada sisa. 🎉',
                    style: AppType.secondaryStrong(c),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog bayar (utang) / terima (piutang) cicilan.
  /// Batas = sisa; lebih = error inline (anti-overpay).
  Future<void> _openPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    DebtEntry entry,
  ) async {
    final d = entry.debt;
    // Controller milik route dialog (_DialogControllers) — lihat catatan
    // insiden 9 Okt 2026 di _openDebtDialog.
    var date = DateTime.now();
    String? amountError;
    bool saving = false;
    final res = await showDialog<String>(
      context: context,
      builder: (c) => _DialogControllers(
        count: 2,
        builder: (c, setS, ctrls) {
          final amountCtrl = ctrls[0];
          final noteCtrl = ctrls[1];
          Future<void> submit() async {
            if (saving) return;
            final amount = parseRp(amountCtrl.text);
              if (amount <= 0) {
                setS(() => amountError =
                    'Isi nominal lebih dari 0.');
                return;
              }
              if (amount > entry.remaining) {
                setS(() => amountError =
                    'Melebihi sisa (${formatRp(entry.remaining)}).');
                return;
              }
              setS(() {
                amountError = null;
                saving = true;
              });
              try {
                await addDebtPayment(ref,
                    debtId: d.id,
                    amount: amount,
                    date: date,
                    note: noteCtrl.text);
              } on DebtOverpayException catch (e) {
                setS(() {
                  saving = false;
                  amountError = e.toString();
                });
                return;
              } catch (_) {
                setS(() {
                  saving = false;
                  amountError =
                      'Gagal menyimpan. Coba lagi.';
                });
                return;
              }
              if (c.mounted) {
                Navigator.pop(
                    c,
                    amount >= entry.remaining
                        ? 'paid_off'
                        : 'saved');
              }
            }

            return AlertDialog(
              title: Text(d.isDebt
                  ? 'Bayar utang — ${d.name}'
                  : 'Terima piutang — ${d.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sisa: ${formatRp(entry.remaining)} '
                      'dari ${formatRp(d.total)}',
                      style: AppType.secondary(c),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandSeparatorInputFormatter()
                      ],
                      decoration: InputDecoration(
                        labelText: 'Nominal (Rp)',
                        hintText:
                            'cth. ${formatAmountField(entry.remaining)}',
                        prefixText: 'Rp ',
                        errorText: amountError,
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _DayTile(
                      label: 'Tanggal',
                      date: date,
                      onTap: () async {
                        final picked =
                            await showDatePicker(
                          context: c,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                              const Duration(days: 365)),
                        );
                        if (picked != null) {
                          HapticFeedback
                              .selectionClick();
                          setS(() => date = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              date.hour,
                              date.minute));
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(c),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: saving ? null : submit,
                    child: Text(
                        saving ? 'Menyimpan…' : 'Simpan')),
              ],
            );
        },
      ),
    );
    if (res != null && context.mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res == 'paid_off'
                ? 'Lunas! 🎉 Saldo ikut berubah.'
                : 'Pembayaran tercatat — saldo ikut berubah.')),
      );
      // Setelah bayar, entry lama basi — buka ulang detail segar.
      if (context.mounted && res == 'paid_off') {
        final fresh =
            await fetchDebts(ref.read(dbProvider));
        final hit = fresh.where((e) => e.debt.id == d.id);
        if (hit.isNotEmpty && context.mounted) {
          _openDebtDetail(context, ref, hit.first);
        }
      }
    }
  }

  Future<void> _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    DebtPayment p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus pembayaran?'),
        content: Text(
          '${formatRp(p.amount)} · ${formatDate(p.date)} akan dihapus '
          'dari riwayat bayar + saldo & riwayat transaksi.',
        ),
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
    if (ok != true || !context.mounted) return;
    await removeDebtPayment(ref, p.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Pembayaran dihapus — saldo ikut berubah.')),
    );
  }
}

/// Ringkasan: total sisa utang vs piutang + progress gabungan.
class _DebtOverview extends ConsumerWidget {
  const _DebtOverview({required this.list});
  final List<DebtEntry> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    var sisaUtang = 0;
    var sisaPiutang = 0;
    var totalUtang = 0;
    var paidUtang = 0;
    var totalPiutang = 0;
    var paidPiutang = 0;
    for (final e in list) {
      if (e.debt.isDebt) {
        totalUtang += e.debt.total;
        paidUtang += e.paid;
        if (!e.done) sisaUtang += e.remaining;
      } else {
        totalPiutang += e.debt.total;
        paidPiutang += e.paid;
        if (!e.done) sisaPiutang += e.remaining;
      }
    }
    final pctU =
        totalUtang == 0 ? 0.0 : (paidUtang / totalUtang).clamp(0.0, 1.0);
    final pctP = totalPiutang == 0
        ? 0.0
        : (paidPiutang / totalPiutang).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan utang-piutang',
              style: AppType.labelMuted(context)),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Sisa utang',
                        style:
                            AppType.labelMuted(context)),
                    Text(display.money(sisaUtang),
                        style: AppType.amount(context)
                            .copyWith(
                                color: AppColors.expenseOf(
                                    context))),
                    const SizedBox(height: 4),
                    AppProgress(
                        value: pctU,
                        color: scheme.error,
                        height: 6),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Sisa piutang',
                        style:
                            AppType.labelMuted(context)),
                    Text(display.money(sisaPiutang),
                        style: AppType.amount(context)
                            .copyWith(
                                color: AppColors.incomeOf(
                                    context))),
                    const SizedBox(height: 4),
                    AppProgress(
                        value: pctP,
                        color: scheme.primary,
                        height: 6),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu baris utang: nama + info tempo + sisa + progress. Tap = detail.
class _DebtItem extends ConsumerWidget {
  const _DebtItem({required this.entry, required this.onTap});
  final DebtEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final d = entry.debt;
    final pct = d.total == 0
        ? 0.0
        : (entry.paid / d.total).clamp(0.0, 1.0);
    final due = d.dueDate;
    final now = DateTime.now();
    final overdue = !entry.done &&
        due != null &&
        DateTime(due.year, due.month, due.day)
            .isBefore(DateTime(now.year, now.month, now.day));
    final sub = entry.done
        ? 'Lunas · ${display.money(d.total)}'
        : [
            d.isDebt ? 'Utang' : 'Piutang',
            'dibayar ${display.money(entry.paid)}',
            if (due != null)
              '${overdue ? 'LEWAT ' : 'tempo '}${display.date(due)}',
          ].join(' · ');
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s12),
        child: Row(
          children: [
            CategoryGlyph(
                emoji: entry.done ? '✅' : '🤝',
                size: 40,
                iconSize: 20),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight:
                                      FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        entry.done
                            ? display.money(d.total)
                            : '−${display.money(entry.remaining)}',
                        style: AppType.amount(context,
                                size: 14)
                            .copyWith(
                          color: entry.done
                              ? AppColors.mutedOf(context)
                              : d.isDebt
                                  ? AppColors.expenseOf(
                                      context)
                                  : AppColors.incomeOf(
                                      context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: overdue
                        ? AppType.secondaryStrong(context)
                            .copyWith(color: scheme.error)
                        : AppType.secondaryStrong(context),
                  ),
                  const SizedBox(height: 6),
                  AppProgress(
                    value: pct,
                    color: entry.done
                        ? AppColors.mutedOf(context)
                        : d.isDebt
                            ? scheme.error
                            : scheme.primary,
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

/// Kepala detail: nama + chip tipe + statistik + aksi edit/hapus.
class _DetailHeader extends ConsumerWidget {
  const _DetailHeader(
      {required this.entry,
      required this.onEdit,
      required this.onDelete});
  final DebtEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final d = entry.debt;
    final pct = d.total == 0
        ? 0.0
        : (entry.paid / d.total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CategoryGlyph(
                emoji: '🤝', size: 44, iconSize: 22),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${d.isDebt ? 'Utang' : 'Piutang'} · '
                    'sejak ${display.date(d.date)}'
                    '${d.dueDate != null ? ' · tempo ${display.date(d.dueDate!)}' : ''}'
                    '${d.note.trim().isNotEmpty ? '\n${d.note.trim()}' : ''}',
                    style: AppType.secondary(context),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Ubah',
              onPressed: onEdit,
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Hapus',
              color: scheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
                child: _DetailStat(
                    label: 'Total',
                    value: display.money(d.total))),
            Expanded(
                child: _DetailStat(
                    label: entry.debt.isDebt
                        ? 'Dibayar'
                        : 'Diterima',
                    value: display.money(entry.paid))),
            Expanded(
                child: _DetailStat(
                    label: 'Sisa',
                    value: display.money(entry.remaining),
                    highlight: !entry.done)),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        AppProgress(
          value: pct,
          color: entry.done
              ? AppColors.mutedOf(context)
              : d.isDebt
                  ? scheme.error
                  : scheme.primary,
          height: 8,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          entry.done
              ? 'Lunas'
              : '${(pct * 100).round()}% dibayar',
          style: AppType.secondary(context),
        ),
      ],
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat(
      {required this.label,
      required this.value,
      this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.labelMuted(context)),
        Text(
          value,
          style: AppType.amount(context, size: 15).copyWith(
              fontWeight:
                  highlight ? FontWeight.w700 : null),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Baris pilih tanggal ala form (label + nilai + ikon kalender + X).
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.placeholder,
    this.onClear,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? placeholder;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          AppType.labelMuted(context)),
                  Text(
                    date == null
                        ? (placeholder ?? 'Pilih tanggal')
                        : formatDate(date!),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Hapus tanggal',
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
