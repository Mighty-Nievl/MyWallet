import 'package:flutter/services.dart';

import 'format.dart';

/// Formatter kolom nominal: ketik `1000` otomatis jadi `1.000`,
/// ketik `1500000` jadi `1.500.000`.
///
/// Hanya digit yang disimpan — parse kembali dengan [parseRp].
/// Dipakai di: form catat, dialog budget, dialog saldo awal.
/// JANGAN dipakai di kolom PIN (Fungsi ini menyisipkan titik).
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    // Batas wajar rupiah (kuadriliun) — cegah int.parse overflow.
    if (digits.length > 15) return oldValue;
    final grouped = formatAmountField(int.parse(digits));
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
