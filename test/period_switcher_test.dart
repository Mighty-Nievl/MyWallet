// Test v1.38.3 — kontrak baris filter periode, hasil ukur screenshot v1.38.2.
//
// Sengaja TERISOLASI: hanya PeriodSwitcher + PeriodNav di dalam MaterialApp,
// tanpa DB/Beranda. Kalau gagal, yang salah widget ini — bukan Home yang
// memang sudah overflow di textScaler 2.0 (lihat catatan di SKILL).
//
// Angka yang dijaga (diukur dari screenshot 1224px / 390dp = 3,14x):
// - empat label = 218,5dp; padding 12dp + jarak 8dp -> 338,5dp, muat di
//   358dp (390 - 2x16 halaman) tanpa scroll;
// - centang M3 dimatikan (dulu memakan ~19dp dan tak terlihat, 1,4:1);
// - label idle #424242 (2,23:1 -> ~9:1);
// - kalender di luar baris filter supaya tak bisa tergeser keluar layar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/period.dart';
import 'package:mywallet/ui/app_theme.dart';
import 'package:mywallet/ui/components/period_switcher.dart';
import 'package:mywallet/ui/design/app_colors.dart';
import 'package:mywallet/ui/design/app_spacing.dart';

const _width = 390.0;

Future<void> _pump(
  WidgetTester tester, {
  double textScale = 1.0,
  bool withNav = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_width, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PeriodSwitcher(),
                    if (withNav)
                      PeriodNav(
                        period: Period.of(
                          PeriodKind.bulanan,
                          DateTime(2026, 10, 22),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _chip(String kind) => find.byKey(ValueKey('period:kind:$kind'));

void main() {
  testWidgets('empat periode muat penuh di 390dp (tidak ada yang kepotong)', (
    tester,
  ) async {
    await _pump(tester);

    // ListView masih ada untuk textScaler besar, tapi di skala normal ia
    // TIDAK boleh bisa di-scroll: kalau bisa, artinya ada chip di luar
    // layar — persis bug v1.38.2 yang memotong "Tahunan" di tengah huruf.
    final scrollable = find.descendant(
      of: find.byType(PeriodSwitcher),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0.0,
      reason: 'empat label + padding wajib muat di 358dp',
    );

    // Dan semuanya benar-benar di dalam layar, tanpa terpotong.
    for (final kind in PeriodKind.values) {
      final rect = tester.getRect(_chip(kind.name));
      expect(
        rect.left,
        greaterThanOrEqualTo(AppSpacing.page - 0.5),
        reason: '${kind.name} menempel keluar kiri',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(_width - AppSpacing.page + 0.5),
        reason: '${kind.name} terpotong di kanan',
      );
    }
  });

  testWidgets('centang M3 dimatikan, padding 12dp, label idle kontras tinggi', (
    tester,
  ) async {
    await _pump(tester);

    final chip = tester.widget<ChoiceChip>(_chip('mingguan'));
    expect(
      chip.showCheckmark,
      isFalse,
      reason: 'centang 1,4:1 itu hantu yang memakan ~19dp lebar',
    );
    // 4 + 8 = 12dp per sisi (dulu 8 + 8), vertikal tetap 8 supaya tinggi
    // pill tidak berubah.
    expect(chip.padding?.horizontal, AppSpacing.s12);
    expect(chip.padding?.vertical, AppSpacing.s8);
    expect(chip.labelPadding?.horizontal, AppSpacing.s8);
    expect(
      chip.labelStyle?.color,
      const Color(0xFF424242),
      reason: 'mutedOf (2,23:1) gagal AA; strongSecondaryOf ~9:1',
    );
    expect(
      chip.side?.color,
      AppTheme.light().colorScheme.outline,
      reason: 'border outlineVariant 1,91:1 nyaris tak terlihat',
    );
    expect(chip.backgroundColor, AppColors.lightSubtle);
  });

  testWidgets('chip terpilih pakai primaryContainer + onPrimaryContainer', (
    tester,
  ) async {
    await _pump(tester);
    final active = tester.widget<ChoiceChip>(_chip('bulanan'));
    expect(active.selected, isTrue);
    expect(
      active.selectedColor,
      AppTheme.light().colorScheme.primaryContainer,
    );
    expect(
      active.labelStyle?.color,
      AppTheme.light().colorScheme.onPrimaryContainer,
    );
    expect(active.labelStyle?.fontWeight, FontWeight.w700);
  });

  testWidgets('kalender di luar baris filter: selalu tampil, tak tergeser', (
    tester,
  ) async {
    await _pump(tester);

    final calendar = find.byKey(const ValueKey('period:calendar'));
    expect(calendar, findsOneWidget);
    // Bukan bagian ListView chip -> tidak bisa ter-scroll keluar layar.
    expect(
      find.descendant(
        of: find.byType(PeriodSwitcher),
        matching: calendar,
      ),
      findsNothing,
    );
    final rect = tester.getRect(calendar);
    expect(rect.right, lessThanOrEqualTo(_width));
    expect(rect.width, greaterThanOrEqualTo(40));
    // Masih di baris navigasi, sejajar dengan chevron.
    expect(
      find.descendant(of: find.byType(PeriodNav), matching: calendar),
      findsOneWidget,
    );
  });

  testWidgets('textScaler 2.0: baris tetap scrollable, kalender tetap ada', (
    tester,
  ) async {
    await _pump(tester, textScale: 2.0);

    final scrollable = find.descendant(
      of: find.byType(PeriodSwitcher),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
      reason: 'di 2,0x chip harus bisa digeser, bukan overflow',
    );
    expect(find.byKey(const ValueKey('period:calendar')), findsOneWidget);
    // Overflow di baris ini bukan jalan keluar yang sah (test terisolasi:
    // tidak ada Home yang memang sudah overflow di 2,0x).
    expect(tester.takeException(), isNull);
  });
}
