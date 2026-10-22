// Penjaga kontras (v1.38.4).
//
// Tiga rilis berturut-turut (v1.37.1, v1.38.2, v1.38.3) isinya sama:
// "terukur X:1, gagal WCAG". Defect yang berulang dengan angka berbeda
// bukan bug warna — tidak ada yang menegakkannya. Test ini menghitung rasio
// kontras dari token ColorScheme + AppColors untuk tema terang DAN gelap,
// jadi pasangan yang pernah bocor tidak bisa bocor lagi tanpa CI merah.
//
// Ambang: 4,5:1 untuk teks normal (WCAG 1.4.3 AA), 3:1 untuk batas
// komponen/grafis (1.4.11). Pasangan yang SENGAJA tidak diuji ada di
// `_decorative` dengan alasannya — kalau mau menambah pengecualian, tulis
// alasannya, jangan dihapus diam-diam.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/design/app_colors.dart';

// Cermin `AppColors.strongSecondaryOf` tanpa BuildContext (dijaga oleh test
// terakhir di file ini: kalau token berubah, test itu yang gagal).
const _strongLight = Color(0xFF424242);
const _strongDark = Color(0xFFE0E0E0);

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pasangan yang tidak diukur di sini, beserta alasannya.
const _decorative = <String, String>{
  'dock:border': 'kapsul dock memakai bayangan + permukaan, border '
      'outlineVariant bukan satu-satunya penanda bentuk',
  'progress:track': 'track gelap bukan informasi; angka % di sebelahnya '
      'yang membawa nilai',
};

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'gelap' : 'terang';

    group('kontras token ($mode)', () {
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      final scheme = theme.colorScheme;
      final bg = dark ? AppColors.darkBackground : AppColors.lightBackground;
      final subtle = dark ? AppColors.darkSubtle : AppColors.lightSubtle;
      final strong = dark ? _strongDark : _strongLight;

      void text(String what, Color fg, Color on) {
        final r = contrastRatio(fg, on);
        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason:
              '$what = ${r.toStringAsFixed(2)}:1 ($mode) — di bawah 4,5:1 '
              'WCAG 1.4.3 untuk teks normal',
        );
      }

      void ui(String what, Color fg, Color on) {
        final r = contrastRatio(fg, on);
        expect(
          r,
          greaterThanOrEqualTo(3.0),
          reason:
              '$what = ${r.toStringAsFixed(2)}:1 ($mode) — di bawah 3:1 '
              'WCAG 1.4.11 untuk batas komponen',
        );
      }

      // Catatan: `expect` tidak boleh dipanggil saat deklarasi `group`
      // (jalan di luar body test → OutsideTestException), jadi semua
      // assertion dibungkus satu `test`.
      test('pasangan token memenuhi ambang WCAG', () {
        // ---- Teks ----
        text('teks utama (onSurface)', scheme.onSurface, bg);
        text('teks sekunder (onSurfaceVariant)', scheme.onSurfaceVariant, bg);
        text('teks sekunder kuat', strong, bg);
        text('label chip idle', strong, subtle);
        text('label periode (onSurface)', scheme.onSurface, scheme.surface);
        text(
          'chip terpilih (onPrimaryContainer)',
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        );
        text('aksi utama (onPrimary)', scheme.onPrimary, scheme.primary);
        text('error (onError)', scheme.onError, scheme.error);

        // ---- Batas komponen ----
        ui('border chip/kartu (outline)', scheme.outline, bg);
        ui('aksen primary', scheme.primary, bg);
      });
    });
  }

  group('pengecualian terdaftar', () {
    for (final entry in _decorative.entries) {
      test(entry.key, () {
        // Bukan assertion: dokumentasi hidup. Gagal kalau alasannya kosong.
        expect(entry.value.trim(), isNotEmpty);
      });
    }
  });

  testWidgets('konstanta uji masih sama dengan token asli', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            expect(AppColors.strongSecondaryOf(context), _strongLight);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            expect(AppColors.strongSecondaryOf(context), _strongDark);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
