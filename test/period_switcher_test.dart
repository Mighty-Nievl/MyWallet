// Test v1.38.3 — kontrak baris filter periode, hasil ukur screenshot v1.38.2.
//
// Sengaja TERISOLASI: hanya PeriodSwitcher + PeriodNav di dalam MaterialApp,
// tanpa DB/Beranda. Kalau gagal, yang salah widget ini — bukan Home yang
// memang sudah overflow di textScaler 2.0.
//
// Yang TIDAK diuji di sini: "empat label muat di 358dp". `flutter_test`
// merender teks dengan font uji berlebar tetap (tiap glyph 1em), jadi
// "Mingguan" terukur ~112dp di test vs ~68dp di HP — assertion lebar di
// sini akan merah untuk alasan yang salah. Klaim muat itu aritmetika dari
// screenshot (218,5dp label + 96dp padding + 24dp jarak = 338,5dp) dan
// diverifikasi di HP user, bukan di test.
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
  testWidgets('baris filter = 4 periode saja, sisanya di luar scroll', (
    tester,
  ) async {
    await _pump(tester);

    // Empat chip, bukan lima: "Kalender" bukan pilihan periode. ListView
    // malas membangun item di luar viewport (font uji lebih lebar dari
    // Roboto), jadi jumlah item dibaca dari delegate: 4 chip + 3 separator
    // = 7. Kalau "Kalender" balik ke baris ini, angkanya jadi 9.
    final list = tester.widget<ListView>(
      find.descendant(
        of: find.byType(PeriodSwitcher),
        matching: find.byType(ListView),
      ),
    );
    final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, PeriodKind.values.length * 2 - 1);
    expect(find.byKey(const ValueKey('period:kind:kalender')), findsNothing);

    // Tanpa ellipsis di level label: kalau teks dipotong, itu clip
    // viewport (bug v1.38.2), bukan pemotongan yang disengaja.
    for (final chip in tester.widgetList<ChoiceChip>(
      find.descendant(
        of: find.byType(PeriodSwitcher),
        matching: find.byType(ChoiceChip),
      ),
    )) {
      final label = chip.label as Text;
      expect(label.overflow, isNot(TextOverflow.ellipsis));
      expect(label.maxLines, isNull);
    }
    // Semua chip ada di dalam layar (kiri), tidak menempel negatif.
    for (final kind in PeriodKind.values) {
      final chip = find.byKey(ValueKey('period:kind:${kind.name}'));
      if (chip.evaluate().isEmpty) continue; // belum dibangun (malas)
      expect(
        tester.getRect(chip).left,
        greaterThanOrEqualTo(AppSpacing.page - 0.5),
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
    // Per sisi 4 (padding) + 8 (labelPadding) = 12dp, dulu 8 + 8 = 16.
    // EdgeInsetsGeometry tak punya `.left`; resolve dulu ke EdgeInsets.
    final padding = chip.padding!.resolve(TextDirection.ltr);
    final labelPadding = chip.labelPadding!.resolve(TextDirection.ltr);
    expect(padding.left, AppSpacing.s4);
    expect(labelPadding.left, AppSpacing.s8);
    expect(
      padding.left + labelPadding.left,
      AppSpacing.s12,
      reason: '12dp per sisi, bukan 16dp',
    );
    // Vertikal tetap 8 supaya tinggi pill tidak berubah.
    expect(padding.vertical, AppSpacing.s16);
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
    // v1.38.6: seleksi dulu cuma fill mint vs abu-abu (1,16:1) sementara
    // border idle 7,36:1 — yang dipilih jadi elemen paling pucat.
    expect(
      active.side?.color,
      AppTheme.light().colorScheme.onPrimaryContainer,
      reason: 'garis chip aktif harus paling tegas di barisnya (~13:1)',
    );
    expect(active.side?.width, 1.5);
  });

  testWidgets('label periode tidak pernah dirender sebagai disabled', (
    tester,
  ) async {
    await _pump(tester);
    // PeriodNav di-pump dengan periode berjalan (22 Okt 2026), jadi ini
    // state DEFAULT yang paling sering dilihat user.
    final chip = tester.widget<ActionChip>(
      find.byKey(const ValueKey('period:label')),
    );
    expect(
      chip.onPressed,
      isNotNull,
      reason:
          'ActionChip disabled membuat M3 menimpa label jadi 38% onSurface '
          '= 3,4:1 di atas #F0F8F0 (gagal AA) dan "Oktober 2026" tampak '
          'tidak bisa dipakai',
    );
    final label = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('period:label')),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(label.style?.color, AppTheme.light().colorScheme.onSurface);
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
