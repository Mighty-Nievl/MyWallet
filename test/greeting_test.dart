import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/ui/greeting.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 10, hour, minute);

  group('greetingTitle: batas jam', () {
    test('03:59 malam, 04:00 pagi', () {
      expect(greetingTitle(at(3, 59)), 'Selamat malam');
      expect(greetingTitle(at(4)), 'Selamat pagi');
    });
    test('10:59 pagi, 11:00 siang', () {
      expect(greetingTitle(at(10, 59)), 'Selamat pagi');
      expect(greetingTitle(at(11)), 'Selamat siang');
    });
    test('14:59 siang, 15:00 sore', () {
      expect(greetingTitle(at(14, 59)), 'Selamat siang');
      expect(greetingTitle(at(15)), 'Selamat sore');
    });
    test('18:59 sore, 19:00 malam', () {
      expect(greetingTitle(at(18, 59)), 'Selamat sore');
      expect(greetingTitle(at(19)), 'Selamat malam');
    });
    test('tengah malam = malam', () {
      expect(greetingTitle(at(0)), 'Selamat malam');
      expect(greetingTitle(at(23, 30)), 'Selamat malam');
    });
  });

  group('resolveGreetingName: manual → Google → null', () {
    test('manual menang atas Google', () {
      expect(
        resolveGreetingName(manualName: 'Budi', googleName: 'ReWin'),
        'Budi',
      );
    });
    test('manual kosong → ikut Google', () {
      expect(
        resolveGreetingName(manualName: '  ', googleName: 'ReWin'),
        'ReWin',
      );
      expect(resolveGreetingName(googleName: 'ReWin'), 'ReWin');
    });
    test('keduanya kosong → null (sapaan polos)', () {
      expect(resolveGreetingName(), isNull);
      expect(
        resolveGreetingName(manualName: ' ', googleName: '  '),
        isNull,
      );
    });
    test('spasi dipangkas', () {
      expect(
        resolveGreetingName(manualName: '  Budi  '),
        'Budi',
      );
    });
  });

  group('greetingText: komposisi', () {
    test('dengan nama pakai koma', () {
      expect(
        greetingText(at(9), manualName: 'Budi'),
        'Selamat pagi, Budi',
      );
    });
    test('tanpa nama tanpa koma menggantung', () {
      expect(greetingText(at(9)), 'Selamat pagi');
      expect(greetingText(at(20)), 'Selamat malam');
    });
    test('nama Google dipakai bila manual kosong', () {
      expect(
        greetingText(at(13, 30), googleName: 'ReWin'),
        'Selamat siang, ReWin',
      );
    });
  });
}
