import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../screens/history_screen.dart';

/// v1.34.0: dua kartu arus kas — Pemasukan & Pengeluaran — di bawah
/// carousel dompet.
///
/// Kenapa kartu terpisah, bukan diselipkan ke kartu saldo: kartu dompet
/// tinggi TETAP 116px ([account_carousel]) dan sudah terbukti overflow
/// 70px di textScaler 2.0 (backlog docs/06). Menambah dua baris nominal
/// di dalamnya dijamin pecah. Kartu sendiri juga membuat angka arus bisa
/// dipindai tanpa membuka Laporan.
///
/// Konteks periode mengikuti [activePeriodProvider] (v1.36.0): Harian,
/// Mingguan, Bulanan, atau Tahunan — bukan selalu bulan. Angka tidak
/// pernah memakai `DateTime.now()` diam-diam: saat user menggeser
/// periode, kartu ikut.
///
/// Delta = perbandingan dengan periode sebelumnya yang setara lewat
/// [prevPeriodTotalsProvider]. Sengaja persen, bukan nominal: "12% lebih
/// besar" lebih mudah dinilai daripada "-Rp340.000" yang harus dihitung
/// sendiri terhadap total.
class FlowCards extends ConsumerWidget {
  const FlowCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(activePeriodProvider);
    final totals = ref.watch(periodTotalsProvider).value;
    final prev = ref.watch(prevPeriodTotalsProvider).value;
    final display = ref.watch(displayPrefsProvider);
    final masuk = totals?.$1 ?? 0;
    final keluar = totals?.$2 ?? 0;
    return IntrinsicHeight(
      // IntrinsicHeight: dua kartu wajib sama tinggi walau salah satu
      // nominalnya panjang (font besar) — tanpa ini kartu terlihat
      // pincang.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FlowCard(
              key: const ValueKey('home:flow-income'),
              label: 'Pemasukan',
              amount: masuk,
              prev: prev?.$1,
              color: AppColors.incomeOf(context),
              icon: Icons.south_west,
              display: display,
              prevLabel: previousPeriodPhrase(period.kind),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _FlowCard(
              key: const ValueKey('home:flow-expense'),
              label: 'Pengeluaran',
              amount: keluar,
              prev: prev?.$2,
              color: AppColors.expenseOf(context),
              icon: Icons.north_east,
              display: display,
              prevLabel: previousPeriodPhrase(period.kind),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    super.key,
    required this.label,
    required this.amount,
    required this.prev,
    required this.color,
    required this.icon,
    required this.display,
    required this.prevLabel,
  });

  final String label;
  final int amount;
  final int? prev;
  final Color color;
  final IconData icon;
  final DisplayPrefs display;

  /// "kemarin" · "minggu lalu" · "bulan lalu" · "tahun lalu".
  final String prevLabel;

  /// Persen perubahan vs periode sebelumnya; null bila tak bisa dihitung
  /// (periode lalu nol — persen dari nol tak bermakna).
  int? get _deltaPct {
    final before = prev;
    if (before == null || before <= 0) return null;
    return ((amount - before) * 100 / before).round();
  }

  String get _deltaText {
    // Nominal disembunyikan: jangan bocorkan arah arus lewat persen.
    if (display.hide && display.scopeAll) return 'perubahan disembunyikan';
    final pct = _deltaPct;
    if (pct == null) {
      if (amount == 0) return 'belum ada catatan';
      return 'baru periode ini';
    }
    if (pct == 0) return 'sama dengan $prevLabel';
    final arrow = pct > 0 ? '▲' : '▼';
    return '$arrow ${pct.abs()}% dari $prevLabel';
  }

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    return Semantics(
      button: true,
      label: '$label, ${display.money(amount)}, $_deltaText',
      // Material = host ripple InkWell (pola v1.33.1: warna di Material,
      // bukan di Container di atasnya).
      child: Material(
        color: AppColors.surfaceOf(context),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: border),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardAll,
          ),
          // Tap → Riwayat: kartu ini ringkasan, detailnya daftar
          // transaksi. Riwayat memakai filter periode yang sama.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                      ),
                      child: Icon(icon, size: 15, color: color),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.labelMuted(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                // FittedBox: nominal panjang (Rp12.345.678) di setengah
                // lebar kartu + font 2.0 tidak boleh overflow — lebih
                // baik mengecil sedikit daripada terpotong.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    display.money(amount),
                    maxLines: 1,
                    style: AppType.amount(context, size: 18).copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  _deltaText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
