import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/period.dart';
import '../../data/providers.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../format.dart';
import '../screens/calendar_screen.dart';

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
///
/// v1.38.3 — diukur dari screenshot rilis v1.38.2 (1224 px / 390dp = 3,14x):
/// 1. `showCheckmark` masih default M3 (nyala) tapi warnanya nyaris sama
///    dengan fill terpilih: kecerahan 46 vs 68 dari 255 (~1,4:1) — centang
///    tak terbaca, namun tetap memakan 37dp ruang kiri (kanan cuma 17,5dp).
///    Ruang itu yang mendorong "Tahunan" keluar layar sampai terpotong di
///    tengah huruf. Centang dimatikan; seleksi dibawa fill + weight.
/// 2. Label idle `mutedOf` = 2,23:1 di atas #F4FBF4 (gagal AA 4,5:1).
///    Naik ke `strongSecondaryOf` (~9:1 di light, ~13:1 di dark).
/// 3. Chip idle hanya dibatasi outlineVariant 1,91:1 → praktis lebur di
///    #FAFAFA. Sekarang fill subtle + border `outline` (~4,4:1).
/// 4. Padding horizontal 16dp -> 12dp: empat label (218,5dp) + padding +
///    jarak = 338,5dp, muat di 358dp tanpa scroll di layar 390dp.
class PeriodSwitcher extends ConsumerWidget {
  const PeriodSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(periodKindProvider);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // v1.38.3: "Kalender" keluar dari baris ini (pindah ke PeriodNav).
        // Sebagai item ke-5 di ListView ia tak pernah terlihat di layar
        // 390dp; menyembunyikan alat navigasi di balik scroll lebih buruk
        // daripada chip yang tak muat.
        itemCount: PeriodKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s8),
        itemBuilder: (context, i) {
          final kind = PeriodKind.values[i];
          final selected = kind == active;
          return ChoiceChip(
            key: ValueKey('period:kind:${kind.name}'),
            label: Text(periodKindLabel(kind)),
            selected: selected,
            // v1.38.3: centang M3 dimatikan — warnanya nyaris sama dengan
            // fill terpilih (~1,4:1) tapi memakan ~19dp lebar, dan lebar
            // itulah yang membuat "Tahunan" terpotong. Seleksi dibawa fill
            // + weight w700.
            showCheckmark: false,
            // Tanpa tema Material 3 penuh, chip terpilih tetap harus
            // terbaca: pakai primaryContainer eksplisit.
            selectedColor: scheme.primaryContainer,
            // v1.38.3: chip idle dulu #F4FBF4 di atas #FAFAFA (1,01:1) —
            // hanya border outlineVariant 1,91:1 yang menandai bentuknya.
            backgroundColor: AppColors.subtleOf(context),
            // v1.38.6: seleksi dulu hanya dibawa fill mint vs abu-abu
            // (1,16:1) sementara border idle 7,36:1 — yang terpilih justru
            // elemen paling pucat di barisnya. Jalannya bukan menipiskan
            // idle (border 7,36:1 itu sudah benar untuk batas komponen,
            // dan menurunkannya melanggar ambang 3:1 di
            // test/contrast_test.dart) melainkan menebalkan sisi yang
            // dipilih: onPrimaryContainer ~13:1 di atas #FAFAFA, jadi chip
            // aktif punya garis paling tegas tanpa merebut warna primary
            // milik tombol aksi (FAB Catat).
            side: selected
                ? BorderSide(color: scheme.onPrimaryContainer, width: 1.5)
                : BorderSide(color: scheme.outline),
            // 4+8 = 12dp horizontal (dulu 8+8 = 16dp), vertikal tetap 8
            // supaya tinggi pill tidak berubah.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s8,
            ),
            labelPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
            ),
            labelStyle: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              // v1.38.3: mutedOf 2,23:1 gagal AA. strongSecondaryOf ~9:1.
              color: selected
                  ? scheme.onPrimaryContainer
                  : AppColors.strongSecondaryOf(context),
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

  /// Slot tombol kalender (v1.38.3) — juga dipakai sebagai penyeimbang kiri
  /// supaya chevron+label tetap di tengah.
  static const double _navSlot = 44;

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
          children: [
            // Penyeimbang selebar tombol kalender: grup chevron+label
            // tetap persis di tengah baris.
            const SizedBox(width: _navSlot),
            Expanded(
              child: Row(
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
                      // v1.38.3: side bawaannya outlineVariant = 1,96:1 di
                      // #FAFAFA; outline ~4,4:1 supaya pill-nya terlihat.
                      side: BorderSide(color: scheme.outline),
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
                        // v1.38.3: terukur 3,88:1. onSurface eksplisit
                        // supaya tidak mewarisi labelStyle chip global.
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                      ),
                      // Ketuk = pulang ke periode berjalan (perilaku sama
                      // dengan chip bulan di AppMonthNav).
                      //
                      // v1.38.6: dulu `isCurrent ? null : ...`. ActionChip
                      // yang disabled membuat M3 menimpa warna label jadi
                      // 38% onSurface — terukur 3,4:1 di atas pill #F0F8F0
                      // (gagal AA) meski `color: scheme.onSurface` sudah
                      // ditulis eksplisit. Dan "Oktober 2026" adalah state
                      // DEFAULT aplikasi, jadi yang paling sering dilihat
                      // adalah label yang tampak tidak bisa dipakai.
                      // Sekarang selalu aktif; saat sudah di periode
                      // berjalan, ketukan tidak mengubah apa pun.
                      onPressed: () {
                        if (isCurrent) return;
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
            ),
            // v1.38.3: Kalender dulu chip ke-5 di ListView switcher — tak
            // pernah terlihat di layar 390dp. Sekarang selalu tampil, dan
            // tempatnya memang di sini: ia navigasi, bukan filter periode.
            SizedBox(
              width: _navSlot,
              height: _navSlot,
              child: IconButton.outlined(
                key: const ValueKey('period:calendar'),
                tooltip: 'Kalender',
                iconSize: 20,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.calendar_month_outlined),
                style: IconButton.styleFrom(
                  minimumSize: const Size(_navSlot, _navSlot),
                  side: BorderSide(color: scheme.outline),
                  foregroundColor: AppColors.mutedOf(context),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                ),
              ),
            ),
          ],
        ),
        if (!isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.micro),
            child: Text(
              'Ketuk label untuk kembali ke ${periodKindLabel(period.kind).toLowerCase()} ini',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.mutedOf(context)),
            ),
          ),
      ],
    );
  }
}
