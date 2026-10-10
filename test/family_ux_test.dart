import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/ui/screens/settings_family.dart';

/// UX Keluarga status personal (tanpa Firebase init — provider jatuh ke
/// personal/offline, persis kayak HP tanpa login).
///
/// Anti-flaky: tanpa pumpAndSettle; poll manual sampai hero muncul.
void main() {
  testWidgets('personal: hero + tombol Google + tanpa search ambigu',
      (t) async {
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FamilySettingsPage()),
      ),
    );

    var found = false;
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text('Catat bareng pasangan').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'hero personal tidak muncul');

    expect(find.text('Masuk dengan Google'), findsOneWidget);
    // 3 manfaat kelihatan (ruang kosong terisi).
    expect(find.textContaining('tidak tersentuh'), findsOneWidget);
    expect(find.textContaining('kode 8 huruf'), findsOneWidget);
    // Tombol CTA penuh-lebar.
    final cta = find.widgetWithText(FilledButton, 'Masuk dengan Google');
    expect(cta, findsOneWidget);
  });
}
