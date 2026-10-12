import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/account_actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/sync_meta.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';

/// Kelola dompet (v1.25): daftar + tambah + arsip/hapus + pindah dana.
///
/// Bahasa form: BackHeader + sheet drag-handle (tanpa isScrollControlled)
/// ikut filter Riwayat; haptic tiap aksi; saldo per dompet via
/// [accountBalanceProvider] (bukan kolom tersimpan — keputusan plan).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BackHeader(title: 'Dompet'),
              const SizedBox(height: AppSpacing.s12),
              Expanded(
                child: accounts.when(
                  loading: () => const AppSkeleton(lines: 3),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(accountsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          icon: '👛',
                          title: 'Belum ada dompet',
                          subtitle:
                              'Tambah dompet pertama lewat tombol di bawah.',
                        )
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(
                            height: AppSpacing.s8,
                          ),
                          itemBuilder: (_, i) =>
                              _AccountCard(account: list[i]),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              SizedBox(
                height: AppSpacing.ctaHeight,
                child: FilledButton.icon(
                  onPressed: () => _addSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Tambah dompet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.bottomPad),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSheet(BuildContext context, WidgetRef ref) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _NameSheet(title: 'Dompet baru'),
    );
    if (name == null || name.trim().isEmpty) return;
    final db = ref.read(dbProvider);
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(name: name.trim()),
        );
  }
}

/// Satu baris dompet: nama + saldo + menu (transfer / arsip / hapus).
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(account.id));
    final display = ref.watch(displayPrefsProvider);
    final selected = ref.watch(selectedAccountProvider) == account.id;
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : AppColors.borderOf(context),
          width: selected ? 2 : AppColors.borderWidthOf(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: AppType.secondaryStrong(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.micro),
                balance.when(
                  loading: () => const AppSkeleton(lines: 1),
                  error: (_, _) => const Text('—'),
                  data: (b) => Text(
                    display.money(b),
                    style: AppType.balance(
                      context,
                    ).copyWith(fontSize: 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.swap_horiz,
            tooltip: 'Pindah dana',
            bordered: false,
            onPressed: () => TransferSheet.show(context, fromId: account.id),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi dompet',
            onSelected: (v) => _menu(context, ref, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Text('Ganti nama'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text('Arsipkan'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, String v) async {
    final db = ref.read(dbProvider);
    switch (v) {
      case 'rename':
        final name = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (_) => _NameSheet(
            title: 'Ganti nama',
            initial: account.name,
          ),
        );
        if (name == null || name.trim().isEmpty) return;
        await (db.update(db.accounts)
              ..where((a) => a.id.equals(account.id)))
            .write(
              AccountsCompanion(
                name: drift.Value(name.trim()),
                updatedAt: drift.Value(syncNow()),
              ),
            );
      case 'archive':
        HapticFeedback.selectionClick();
        await archiveAccount(db, account.id);
      case 'delete':
        if (!await accountDeletable(db, account.id)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dompet berisi — arsipkan, jangan hapus.'),
            ),
          );
          return;
        }
        if (!context.mounted) return;
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Hapus dompet?'),
            content: Text(
              'Dompet "${account.name}" kosong dan akan dihapus permanen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (yes == true) await deleteAccount(db, account.id);
    }
  }
}

/// Sheet nama dompet (tambah + ganti-nama satu widget). Return nama.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s8,
          AppSpacing.page,
          AppSpacing.sectionGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppType.sectionTitle(context)),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'cth. Pribadi, Keluarga, Darurat',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              height: AppSpacing.ctaHeight,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, _ctrl.text);
  }
}

/// Dialog pindah dana antar-dompet (v1.25).
///
/// Warning overdraft (bukan blokir — keputusan plan): bila nominal >
/// saldo asal, baris kuning "Saldo asal tak cukup — lanjut?" muncul;
/// tombol tetap aktif. Saldo asal live via [accountBalanceProvider].
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key, this.fromId});

  /// Dompet asal awal (tombol ⇄ di kartu) — null = dompet aktif/global.
  final int? fromId;

  /// Helper satu baris untuk tombol ⇄ (tanpa import State).
  static Future<void> show(BuildContext context, {int? fromId}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => TransferSheet(fromId: fromId),
    );
  }

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _fromId;
  int? _toId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromId = widget.fromId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s8,
          AppSpacing.page,
          AppSpacing.sectionGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pindah dana', style: AppType.sectionTitle(context)),
            const SizedBox(height: AppSpacing.s12),
            accounts.when(
              loading: () => const AppSkeleton(lines: 2),
              error: (_, _) => const Text('Dompet gagal dimuat.'),
              data: (list) => _form(context, list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, List<Account> list) {
    _fromId ??= ref.watch(selectedAccountProvider);
    _fromId ??= list.isNotEmpty ? list.first.id : null;
    _toId ??= list.length > 1
        ? list.firstWhere((a) => a.id != _fromId).id
        : null;
    final fromBalance = _fromId == null
        ? null
        : ref.watch(accountBalanceProvider(_fromId!)).value;
    final amount = int.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;
    final overdraft =
        fromBalance != null && amount > 0 && amount > fromBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AccountDropdown(
          label: 'Dari',
          accounts: list,
          value: _fromId,
          exclude: _toId,
          onPick: (v) => setState(() => _fromId = v),
        ),
        const SizedBox(height: AppSpacing.s8),
        _AccountDropdown(
          label: 'Ke',
          accounts: list,
          value: _toId,
          exclude: _fromId,
          onPick: (v) => setState(() => _toId = v),
        ),
        const SizedBox(height: AppSpacing.s8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (fromBalance != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Saldo asal: ${ref.watch(displayPrefsProvider).money(fromBalance)}',
            style: AppType.labelMuted(context),
          ),
        ],
        if (overdraft) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Saldo asal tak cukup — tetap lanjut?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          height: AppSpacing.ctaHeight,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Pindahkan'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final amount = int.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;
    if (_fromId == null || _toId == null) {
      setState(() => _error = 'Pilih dompet asal dan tujuan.');
      return;
    }
    if (_fromId == _toId) {
      setState(() => _error = 'Dompet asal dan tujuan harus beda.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari 0.');
      return;
    }
    try {
      await moveTransfer(
        ref,
        fromAccountId: _fromId!,
        toAccountId: _toId!,
        amount: amount,
        date: DateTime.now(),
        note: _noteCtrl.text,
      );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? 'Gagal memindahkan.');
    }
  }
}

/// Dropdown dompet native (pilihan sadar: opsi lawan disembunyikan agar
/// asal ≠ tujuan mustahil dipilih — validasi ganda di _submit).
class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.exclude,
    required this.onPick,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final int? exclude;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    final items = accounts.where((a) => a.id != exclude).toList();
    return DropdownButtonFormField<int>(
      initialValue: items.any((a) => a.id == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final a in items)
          DropdownMenuItem(value: a.id, child: Text(a.name)),
      ],
      onChanged: onPick,
    );
  }
}
