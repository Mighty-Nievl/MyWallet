import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings.dart';
import 'format.dart';

/// Preferensi tampilan nominal & tanggal dalam satu paket,
/// agar widget cukup watch satu provider.
class DisplayPrefs {
  const DisplayPrefs({
    required this.hide,
    required this.scopeAll,
    required this.compactAmounts,
    required this.relativeDates,
    required this.showIcons,
  });

  /// Nominal disembunyikan (toggle privacy aktif).
  final bool hide;

  /// true = sembunyikan SEMUA nominal; false = hanya saldo.
  final bool scopeAll;

  /// Nominal ringkas (Rp25 rb) vs penuh (Rp25.000).
  final bool compactAmounts;

  /// Tanggal relatif ("Hari ini") vs absolut ("7 Okt 2026").
  final bool relativeDates;

  /// Tampilkan ikon emoji kategori di list.
  final bool showIcons;

  /// Format nominal sesuai privacy + gaya kompak.
  String money(int amount) {
    if (hide && scopeAll) return 'Rp••••';
    return compactAmounts ? formatRpCompact(amount) : formatRp(amount);
  }

  /// Nominal RINGKAS paksa — untuk sel kalender yang sempit.
  /// Tetap hormat privacy: scope "semua nominal" = tersamar.
  String compact(int amount) {
    if (hide && scopeAll) return 'Rp••••';
    return formatRpCompact(amount);
  }

  /// Nominal bertanda -/+ untuk list transaksi & ringkasan.
  String signed(int amount, {required bool isExpense}) {
    final sign = isExpense ? '-' : '+';
    return '$sign${money(amount)}';
  }

  /// Format tanggal sesuai preferensi relatif/absolut.
  String date(DateTime d) =>
      relativeDates ? formatDateRelative(d) : formatDate(d);
}

/// Gabungan preferensi display. Berubah otomatis tiap ada setting diubah.
final displayPrefsProvider = Provider<DisplayPrefs>((ref) {
  final hide = ref.watch(hideBalanceProvider).value ?? false;
  final scope = ref.watch(privacyScopeProvider).value ?? 'balance';
  final compact = ref.watch(compactAmountsProvider).value ?? false;
  final relative = ref.watch(relativeDatesProvider).value ?? true;
  final icons = ref.watch(showCategoryIconsProvider).value ?? true;
  return DisplayPrefs(
    hide: hide,
    scopeAll: scope == 'all',
    compactAmounts: compact,
    relativeDates: relative,
    showIcons: icons,
  );
});
