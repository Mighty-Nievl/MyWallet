import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/data/household.dart';

void main() {
  group('InviteCode.generate', () {
    test('8 char alfabet valid', () {
      final c = InviteCode.generate(Random(42));
      expect(c, hasLength(8));
      expect(InviteCode.validPattern.hasMatch(c), isTrue);
    });

    test('100 kode acak unik semua', () {
      final r = Random(7);
      final set = {for (var i = 0; i < 100; i++) InviteCode.generate(r)};
      expect(set, hasLength(100));
    });

    test('tanpa char ambigu I O 0 1', () {
      final r = Random(99);
      for (var i = 0; i < 50; i++) {
        final c = InviteCode.generate(r);
        expect(c.contains('I'), isFalse);
        expect(c.contains('O'), isFalse);
        expect(c.contains('0'), isFalse);
        expect(c.contains('1'), isFalse);
      }
    });
  });

  group('InviteCode.format/parse/isValid', () {
    test('format ABCD-EFGH', () {
      expect(InviteCode.format('ABCDEFGH'), 'ABCD-EFGH');
    });

    test('parse buang dash + spasi + lowercase', () {
      expect(InviteCode.parse('abcd-efgh'), 'ABCDEFGH');
      expect(InviteCode.parse(' ab cd '), 'ABCD');
    });

    test('isValid terima format mentah user', () {
      expect(InviteCode.isValid('ABCD-EFGH'), isTrue);
      expect(InviteCode.isValid('abcdefgh'), isTrue);
      expect(InviteCode.isValid('ABC'), isFalse);
      expect(InviteCode.isValid('ABCDEFGH1'), isFalse);
      expect(InviteCode.isValid('ABCD-IFGH'), isFalse); // I ambigu
    });
  });

  group('InviteCode.isExpired (TTL 24 jam)', () {
    test('batas TTL = 24 jam', () {
      expect(HouseholdPaths.inviteTtl, const Duration(hours: 24));
    });

    test('belum lewat → false, lewat → true', () {
      final now = DateTime(2026, 10, 10, 12);
      expect(
          InviteCode.isExpired(now.add(const Duration(hours: 1)), now),
          isFalse);
      expect(
          InviteCode.isExpired(
              now.subtract(const Duration(seconds: 1)), now),
          isTrue);
    });
  });

  group('friendlyAuthError (Indonesia, tanpa SDK)', () {
    test('batal → dibatalkan', () {
      expect(friendlyAuthError(Exception('sign_in_canceled')),
          'Login dibatalkan.');
    });

    test('offline → internet + data aman', () {
      final m = friendlyAuthError(Exception('network Failed host lookup'));
      expect(m, contains('internet'));
      expect(m, contains('Data lokal tetap aman'));
    });

    test('SHA-1 salah → hubungi Rezal', () {
      expect(friendlyAuthError(Exception('DEVELOPER_ERROR 10:')),
          contains('Hubungi Rezal'));
    });

    test('config v7: clientConfigurationError → hubungi Rezal', () {
      expect(
          friendlyAuthError(Exception(
              'GoogleSignInException(code GoogleSignInExceptionCode.clientConfigurationError, serverClientId must be provided, null)')),
          contains('Hubungi Rezal'));
    });

    test('provider belum nyala: operation-not-allowed → hubungi Rezal', () {
      expect(
          friendlyAuthError(Exception(
              '[firebase_auth/operation-not-allowed] The identity provider is not enabled.')),
          contains('belum diaktifkan'));
    });

    test('akun dinonaktifkan → coba akun lain', () {
      expect(friendlyAuthError(Exception('[firebase_auth/user-disabled]')),
          contains('dinonaktifkan'));
    });

    test('idToken kosong → hubungi Rezal', () {
      expect(friendlyAuthError(StateError('empty-id-token')),
          contains('Hubungi Rezal'));
    });

    test('desktop → hanya HP Android', () {
      expect(friendlyAuthError(StateError('unsupported-platform')),
          contains('Android'));
    });

    test('lainnya → coba lagi', () {
      expect(friendlyAuthError(Exception('aneh banget')),
          'Login gagal — coba lagi.');
    });
  });

  group('friendlyJoinError', () {
    test('tiga alasan beda pesan', () {
      expect(friendlyJoinError(JoinFailure.badCode), contains('tidak valid'));
      expect(
          friendlyJoinError(JoinFailure.notFound), contains('tidak dikenal'));
      expect(friendlyJoinError(JoinFailure.expired), contains('kedaluwarsa'));
    });
  });
}
