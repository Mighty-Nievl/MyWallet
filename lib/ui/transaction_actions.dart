import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_actions.dart';
import '../data/database.dart';
import '../data/providers.dart';
import 'design/app_spacing.dart';
import 'design/app_typography.dart';
import 'format.dart';
import 'screens/tx_form_screen.dart';

/// Pintu aksi transaksi (v1.36.2).
///
/// Kaki transfer TIDAK boleh masuk [TxFormScreen]: mengedit/menghapus
/// satu sisi merusak pasangan saldo. Transfer dibuka sebagai ringkasan +
/// hapus berpasangan. Transaksi biasa tetap ke form edit lama.
Future<void> openTransaction(
  BuildContext context,
  WidgetRef ref,
  TxWithCategory tx,
) async {
  final db = ref.read(dbProvider);
  final row = await (db.select(
    db.transactions,
  )..where((t) => t.id.equals(tx.id))).getSingleOrNull();
  if (!context.mounted) return;
  if (row?.transferId == null) {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TxFormScreen(existing: tx)));
    return;
  }
  await showTransferActions(context, ref, row!);
}

/// Ringkasan transfer + hapus kedua kaki. Edit satu sisi sengaja tidak
/// disediakan; ubah = hapus lalu buat transfer baru.
Future<void> showTransferActions(
  BuildContext context,
  WidgetRef ref,
  Transaction leg,
) async {
  final groupId = leg.transferId;
  if (groupId == null) return;

  final db = ref.read(dbProvider);
  final legs = await transferLegs(db, groupId);
  final accounts = await db.select(db.accounts).get();
  final out = legs.where((t) => t.isExpense).firstOrNull ?? leg;
  final into = legs.where((t) => !t.isExpense).firstOrNull;
  String nameOf(int? id) =>
      accounts.where((a) => a.id == id).map((a) => a.name).firstOrNull ??
      'Dompet';
  final rawNote = leg.note == 'Transfer'
      ? ''
      : leg.note.replaceFirst('Transfer · ', '');

  if (!context.mounted) return;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
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
            Text('Transfer antar dompet', style: AppType.sectionTitle(ctx)),
            const SizedBox(height: AppSpacing.s12),
            _InfoRow(label: 'Dari', value: nameOf(out.accountId)),
            _InfoRow(
              label: 'Ke',
              value: into == null ? '—' : nameOf(into.accountId),
            ),
            _InfoRow(label: 'Nominal', value: formatRp(out.amount)),
            _InfoRow(label: 'Tanggal', value: formatDate(out.date)),
            if (rawNote.isNotEmpty) _InfoRow(label: 'Catatan', value: rawNote),
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Transfer tidak bisa diedit per sisi supaya saldo dua '
                'dompet tetap seimbang. Untuk mengubah, hapus lalu buat '
                'transfer baru.',
                style: AppType.secondary(ctx),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    child: const Text('Hapus transfer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (action != 'delete' || !context.mounted) return;

  final yes = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Hapus transfer?'),
      content: const Text(
        'Kedua sisi transfer (keluar dan masuk) akan dihapus. '
        'Tindakan ini tidak bisa diurungkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (yes != true) return;

  await deleteTransfer(db, groupId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Transfer dihapus dari kedua dompet.')),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.micro),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: AppType.secondary(context)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.secondaryStrong(context),
            ),
          ),
        ],
      ),
    );
  }
}
