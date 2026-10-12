import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../components/b2c_chip.dart';
import '../design/app_spacing.dart';

/// Pemilih dompet Beranda (v1.25): strip chip horizontal di bawah hero.
///
/// - Selalu ada "Semua" (gabungan, default — nol berubah utk user lama).
/// - Dompet terarsip disembunyikan (keputusan plan); kelola buka sheet.
/// - Chip geser hilang bila 1 dompet + tak perlu pilih (hemat vertikal).
///
/// Bahasa form: constraints 48px + elipsis ikut B2CFilterChip (tanpa
/// hitung manual). Haptic ikut chip.
class AccountPicker extends ConsumerWidget {
  const AccountPicker({super.key, this.onManage});

  /// Dibuka saat tap "Kelola" — layar induk pasok (navigasi milik caller).
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final selected = ref.watch(selectedAccountProvider);

    return accounts.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.length < 2 && onManage == null) {
          return const SizedBox.shrink();
        }
        return _strip(context, ref, list, selected);
      },
    );
  }

  Widget _strip(
    BuildContext context,
    WidgetRef ref,
    List<Account> list,
    int? selected,
  ) {
    void pick(int? id) {
      HapticFeedback.selectionClick();
      ref.read(selectedAccountProvider.notifier).state = id;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          B2CFilterChip(
            label: 'Semua',
            selected: selected == null,
            onTap: () => pick(null),
          ),
          for (final a in list) ...[
            const SizedBox(width: AppSpacing.s8),
            B2CFilterChip(
              label: a.name,
              selected: selected == a.id,
              onTap: () => pick(a.id),
            ),
          ],
          if (onManage != null) ...[
            const SizedBox(width: AppSpacing.s8),
            _ManageChip(onTap: onManage!),
          ],
        ],
      ),
    );
  }
}

/// Tombol "Kelola" seukuran chip (outline, ikon + label) — bukan chip
/// filter (tak punya state selected), jadi widget sendiri.
class _ManageChip extends StatelessWidget {
  const _ManageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Kelola dompet',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wallet_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s4),
              Text(
                'Kelola',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
