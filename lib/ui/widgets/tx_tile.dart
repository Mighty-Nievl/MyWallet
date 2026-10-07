import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../components/category_icon.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';

/// Satu baris transaksi untuk dipakai di Beranda & Riwayat.
/// Nominal, tanggal, dan ikon mengikuti preferensi Tampilan.
///
/// Public API TETAP (STEP 1B): [tx] + [onTap].
/// Hanya visual yang diubah — baris bersih ala fintech modern:
/// ikon subtle, judul jelas, info sekunder muted, nominal tegas.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, this.onTap});

  final TxWithCategory tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final amountColor = tx.isExpense ? scheme.error : scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Row(
          children: [
            if (display.showIcons) ...[
              CategoryIcon(icon: tx.catIcon ?? '📦'),
              const SizedBox(width: AppSpacing.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.note.isNotEmpty
                        ? tx.note
                        : (tx.catName ?? 'Tanpa kategori'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.catName ?? 'Tanpa kategori'} · ${display.date(tx.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.secondary(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(
              display.signed(tx.amount, isExpense: tx.isExpense),
              style: AppType.amount(context).copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
