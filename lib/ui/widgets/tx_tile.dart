import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../components/app_card.dart';
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
/// Layout dua-baris (v1.24.10, request user): baris 1 = catatan
/// full-width; baris 2 = kategori kiri + nominal kanan. Alasan L2 —
/// layout lama (judul + nominal dua Expanded sejajar) bikin keduanya
/// rebutan satu baris horizontal: catatan sedikit panjang langsung
/// ellipsis padahal ruang vertikal masih lega.
///
/// [showDate]: tampilkan tanggal di baris 2 (belakang kategori).
/// Beranda (v1.24.4) pakai false karena tanggal sudah ada di header
/// grup ("Kemarin", "9 Okt 2026"). Riwayat grup (v1.24.8) juga false.
/// Flat tanpa grup pakai true (default): tanggal per baris di sana
/// itu informasi, bukan redundansi.
///
/// [dense]: kepadatan arsip (v1.24.9) — padding vertikal s8, khusus
/// Riwayat yang list-nya panjang. Beranda (teaser 5 item) tetap lega s12.
///
/// [showAccount]: tampilkan nama dompet di meta (v1.30 — label dompet).
/// Caller nyalakan bila >1 dompet; tx lama/dompet terhapus (null)
/// tetap disembunyikan (jujur, bukan "Semua").
class TxTile extends ConsumerWidget {
  const TxTile({
    super.key,
    required this.tx,
    this.onTap,
    this.showDate = true,
    this.dense = false,
    this.showAccount = false,
  });

  final TxWithCategory tx;
  final VoidCallback? onTap;
  final bool showDate;
  final bool dense;
  final bool showAccount;

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
    // nama kategori → baris 2 jadi tanggal saja / disembunyikan total
    // kalau keduanya kosong, biar kolom lega dan nol "Ke...").
    final catName = tx.catName ?? 'Tanpa kategori';
    final hasNote = tx.note.isNotEmpty;
    final title = hasNote ? tx.note : catName;
    // v1.30: meta dari PARTS (bukan string tempel) — tiap dimensi bisa
    // hilang sendiri: judul=kategori → kategori off; grup tanggal →
    // tanggal off; 1 dompet/null → dompet off. Nol "·" gantung.
    final parts = <String>[];
    if (hasNote) parts.add(catName);
    if (showDate) parts.add(display.date(tx.date));
    final acct = tx.accountName;
    if (showAccount && acct != null && acct.isNotEmpty) parts.add(acct);
    final meta = parts.join(' · ');
    final tap = onTap;
    // Karakteristik #5 (v1.30): tiap baris = kartu kecil (bukan teks
    // polos) — padding s12, glyph 40, radius kartu + shadow lembut.
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: InkWell(
        onTap: tap == null
            ? null
            : () {
                // B2C v1.20: umpan sentuh ringan di tiap baris transaksi.
                HapticFeedback.selectionClick();
                tap();
              },
        // v1.30: splash ikut radius wadah AppCard (kartu, bukan md).
        borderRadius: AppRadius.cardAll,
        child: Padding(
          // v1.24.9: dense = arsip rapat s8 (Riwayat); default lega s12
          // (Beranda teaser 5 item — kritik L2: 24px antar-baris boros
          // untuk arsip 50 baris).
          padding: EdgeInsets.symmetric(
            vertical: dense ? AppSpacing.s4 : AppSpacing.s8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (display.showIcons) ...[
                CategoryGlyph(emoji: tx.catIcon ?? '📦', size: 40),
                const SizedBox(width: AppSpacing.s12),
              ],
              // v1.24.10: kolom teks full-width — baris 1 catatan, baris 2
              // meta kiri + nominal kanan (rebutan horizontal dihapus).
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
                    // v1.24.4: baris 2 cuma dirender kalau ada isinya
                    // (Beranda tanpa-catatan = kosong total → judul saja).
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.micro),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.secondaryStrong(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          // v1.24.5: nominal TETAP Expanded + rata kanan —
                          // dua slot 1:1 → tepi kanan sejajar vertikal
                          // (kritik screenshot: -Rp8.000 mundur vs
                          // -Rp300.000). Yang menyusut saat sempit = meta
                          // (ellipsis), bukan nominal. Anti-overflow 300px.
                          Expanded(
                            child: Text(
                              display.signed(
                                tx.amount,
                                isExpense: tx.isExpense,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: AppType.amount(
                                context,
                              ).copyWith(color: amountColor),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.micro),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          display.signed(tx.amount, isExpense: tx.isExpense),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: AppType.amount(
                            context,
                          ).copyWith(color: amountColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Seluruh baris tap → edit: chevron sebagai affordance.
              // v1.24.5: chevron DIJANGKAR tepi layar (bukan nempel ujung
              // teks) → kolom chevron stabil, tidak wobble ikut panjang
              // nominal.
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
      ),
    );
  }
}
