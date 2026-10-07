import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../display.dart';

/// Satu baris transaksi untuk dipakai di Beranda & Riwayat.
/// Nominal, tanggal, dan ikon mengikuti preferensi Tampilan.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, this.onTap});

  final TxWithCategory tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final color = tx.isExpense ? scheme.error : scheme.primary;
    return ListTile(
      dense: true,
      leading: display.showIcons
          ? CircleAvatar(
              child: Text(tx.catIcon ?? '📦',
                  style: const TextStyle(fontSize: 18)),
            )
          : null,
      title: Text(
        tx.note.isNotEmpty ? tx.note : (tx.catName ?? 'Tanpa kategori'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${tx.catName ?? 'Tanpa kategori'} · ${display.date(tx.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        display.signed(tx.amount, isExpense: tx.isExpense),
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      onTap: onTap,
    );
  }
}
