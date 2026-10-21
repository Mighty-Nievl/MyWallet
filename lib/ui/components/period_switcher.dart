import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/period.dart';
import '../../data/providers.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../format.dart';

/// Switcher periode (v1.35.0): Harian · Mingguan · Bulanan · Tahunan.
///
/// Kenapa chip scroll horizontal, bukan `SegmentedButton`: empat label
/// berbahasa Indonesia ("Mingguan") di layar 390dp sudah ~330dp; di
/// textScaler 2.0 melewati lebar layar dan `SegmentedButton` tidak bisa
/// di-scroll → overflow kuning-hitam. Row scrollable selalu aman.
///
/// Memilih "Bulanan" menyinkronkan `selectedMonthProvider` ke bulan yang
/// sedang dilihat, supaya layar yang MASIH bulanan (Riwayat, Budget,
/// grafik 6 bulan) tidak diam-diam menampilkan bulan lain.
class PeriodSwitcher extends ConsumerWidget {
  const PeriodSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(periodKindProvider);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PeriodKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s8),
        itemBuilder: (context, i) {
          final kind = PeriodKind.values[i];
          final selected = kind == active;
          return ChoiceChip(
            key: ValueKey('period:kind:${kind.name}'),
            label: Text(periodKindLabel(kind)),
            selected: selected,
            // Tanpa tema Material 3 penuh, chip terpilih tetap harus
            // terbaca: pakai primaryContainer eksplisit.
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : AppColors.mutedOf(context),
            ),
            onSelected: (_) {
              ref.read(periodKindProvider.notifier).state = kind;
              // Bulanan = jembatan ke layar yang masih bulanan.
              if (kind == PeriodKind.bulanan) {
                final p = Period.of(kind, ref.read(periodAnchorProvider));
                ref.read(periodAnchorProvider.notifier).state = p.start;
                ref.read(selectedMonthProvider.notifier).state = monthKey(
                  p.start,
                );
              }
            },
          );
        },
      ),
    );
  }
}

/// Navigasi periode: chevron kiri/kanan + chip label + jalan pintas
/// "kembali ke periode ini" saat sedang menjelajah.
///
/// Menggantikan `AppMonthNav` di layar yang mengikuti switcher, dengan
/// bahasa visual yang sama supaya perpindahan tidak terasa seperti dua
/// aplikasi berbeda.
class PeriodNav extends ConsumerWidget {
  const PeriodNav({super.key, required this.period});

  final Period period;

  void _shift(WidgetRef ref, int delta) {
    final next = period.shift(delta);
    ref.read(periodAnchorProvider.notifier).state = next.start;
    // Jaga layar bulanan tetap sejalan saat periode = bulan.
    if (next.kind == PeriodKind.bulanan) {
      ref.read(selectedMonthProvider.notifier).state = monthKey(next.start);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = period.containsToday();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('period:prev'),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Periode sebelumnya',
              onPressed: () => _shift(ref, -1),
            ),
            const SizedBox(width: AppSpacing.s4),
            Flexible(
              child: ActionChip(
                key: const ValueKey('period:label'),
                avatar: Icon(
                  isCurrent
                      ? Icons.today_outlined
                      : Icons.history_toggle_off_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text(
                  periodLabel(period),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Ketuk = pulang ke periode berjalan (perilaku sama
                // dengan chip bulan di AppMonthNav).
                onPressed: isCurrent
                    ? null
                    : () {
                        final now = DateTime.now();
                        ref.read(periodAnchorProvider.notifier).state =
                            DateTime(now.year, now.month, now.day);
                        if (period.kind == PeriodKind.bulanan) {
                          ref.read(selectedMonthProvider.notifier).state =
                              currentMonthKey();
                        }
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            IconButton(
              key: const ValueKey('period:next'),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Periode berikutnya',
              onPressed: () => _shift(ref, 1),
            ),
          ],
        ),
        if (!isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.micro),
            child: Text(
              'Ketuk label untuk kembali ke ${periodKindLabel(period.kind).toLowerCase()} ini',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedOf(context),
              ),
            ),
          ),
      ],
    );
  }
}
