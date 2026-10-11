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
///
/// [showDate]: tampilkan tanggal di subtitle. Beranda (v1.24.4) pakai
/// false karena tanggal sudah ada di header grup ("Kemarin",
/// "9 Okt 2026") — ngulang di tiap baris cuma bikin kepotong "Ke...".
/// Riwayat (flat, tanpa grup) pakai true (default): tanggal per baris
/// di sana itu informasi, bukan redundansi.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, this.onTap, this.showDate = true});

  final TxWithCategory tx;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    // Semantik nominal satu sumber kebenaran (AppColors), sama dengan
    // hero Beranda dan strip "Hari ini".
    final amountColor = tx.isExpense
        ? AppColors.expenseOf(context)
        : AppColors.incomeOf(context);
    // v1.24.4: subtitle cerdas — tanpa tanggal di grup Beranda (showDate
    // false), tanpa duplikat kategori saat catatan kosong (judul sudah
    // nama kategori → subtitle jadi tanggal saja / disembunyikan total
    // kalau keduanya kosong, biar kolom lega dan nol "Ke...").
    final catName = tx.catName ?? 'Tanpa kategori';
    final hasNote = tx.note.isNotEmpty;
    final title = hasNote ? tx.note : catName;
    final datePart = showDate ? display.date(tx.date) : '';
    final subtitle = hasNote
        ? (showDate ? '$catName · $datePart' : catName)
        : datePart;
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // v1.24.4: subtitle cuma dirender kalau ada isinya
                  // (Beranda tanpa-catatan = kosong total → judul saja).
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.secondaryStrong(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                display.signed(tx.amount, isExpense: tx.isExpense),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppType.amount(context).copyWith(color: amountColor),
              ),
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
