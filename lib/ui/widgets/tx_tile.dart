import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../format.dart';

/// Satu baris transaksi untuk dipakai di Beranda & Riwayat.
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onTap});

  final TxWithCategory tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tx.isExpense
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;
    final sign = tx.isExpense ? '-' : '+';
    return ListTile(
      leading: CircleAvatar(
        child: Text(tx.catIcon ?? '📦', style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        tx.note.isNotEmpty ? tx.note : (tx.catName ?? 'Tanpa kategori'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${tx.catName ?? 'Tanpa kategori'} · ${formatDate(tx.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$sign${formatRp(tx.amount)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      onTap: onTap,
    );
  }
}
