import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../components/category_glyph.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';

/// Satu baris transaksi untuk dipakai di Beranda & Riwayat.
/// Nominal, tanggal, dan ikon mengikuti preferensi Tampilan.
///
/// Public API TETAP (STEP 1B): [tx] + [onTap].
/// Visual: glyph monochrome aksen, judul jelas, info sekunder
/// kontras tinggi (mudah dibaca), nominal tegas.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, this.onTap});

  final TxWithCategory tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    // Semantik nominal satu sumber kebenaran (AppColors), sama dengan
    // hero Beranda dan strip "Hari ini".
    final amountColor = tx.isExpense
        ? AppColors.expenseOf(context)
        : AppColors.incomeOf(context);
    final tap = onTap;
    return InkWell(
      onTap: tap == null
          ? null
          : () {
              // B2C v1.20: umpan sentuh ringan di tiap baris transaksi.
              HapticFeedback.selectionClick();
              tap();
            },
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Row(
          children: [
            if (display.showIcons) ...[
              CategoryGlyph(emoji: tx.catIcon ?? '📦'),
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
                    style: AppType.secondaryStrong(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(
              display.signed(tx.amount, isExpense: tx.isExpense),
              style: AppType.amount(context).copyWith(color: amountColor),
            ),
            // Seluruh baris tap → edit: chevron sebagai affordance.
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.s4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
