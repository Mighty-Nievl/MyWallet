import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/auth_service.dart';
import 'package:mywallet/ui/screens/family_screen.dart';

/// UX Keluarga status personal (tanpa Firebase init — provider jatuh ke
/// personal/offline, persis kayak HP tanpa login).
///
/// v1.27: halaman mandiri (dulu sub-Pengaturan) + tanpa search bar.
///
/// Anti-flaky: tanpa pumpAndSettle; poll manual sampai hero muncul.
void main() {
  testWidgets('personal: hero + tombol Google + tanpa search ambigu',
      (t) async {
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FamilyScreen()),
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
    // v1.27: search bar dibuang — halaman 2 grup tak butuh cari.
    expect(find.text('Cari di Keluarga…'), findsNothing);
  });

  test('bootTimeout 8 detik — boot nggak boleh hang selamanya', () {
    // Regresi insiden v1.17.2: CredentialManager nyangkut bikin future
    // menggantung; timeout menjamin halaman keluar dari skeleton.
    expect(AuthService.bootTimeout, const Duration(seconds: 8));
  });

  test('timeout signIn berlapis — tombol nggak macet Menghubungkan', () {
    // Regresi audit v1.17.3: signIn tanpa timeout bikin tombol macet
    // selamanya di sinyal lemot (0,24 KB/S). Google interaktif paling
    // lama (user pilih akun), store paling pendek.
    expect(AuthService.signInGoogleTimeout, const Duration(seconds: 60));
    expect(AuthService.signInFirebaseTimeout, const Duration(seconds: 45));
    expect(AuthService.signInStoreTimeout, const Duration(seconds: 20));
  });
}
