import 'dart:async';
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

    test('timeout jaringan → pesan internet + data aman', () {
      final m = friendlyAuthError(TimeoutException('after 0:00:20'));
      expect(m, contains('lambat'));
      expect(m, contains('Data lokal tetap aman'));
    });

    test('timeout = WiFi zonk (0,76 KB/S), bukan tanpa sinyal', () {
      // Firestore gagal handshake dalam 20 dtk padahal radio nyala:
      // pesan harus suruh pindah jaringan, bukan bunuh app.
      final m = friendlyAuthError(Exception('TimeoutException after 20s'));
      expect(m, isNot(contains('Tidak ada internet')));
      expect(m, contains('sinyal kuat'));
      expect(m, contains('Data lokal tetap aman'));
    });

    test('permission-denied → hubungi Rezal (rules belum dibuka)', () {
      expect(
          friendlyAuthError(Exception(
              '[cloud_firestore/permission-denied] Missing or insufficient permissions.')),
          contains('Hubungi Rezal'));
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

  group('v1.18 production-grade: validasi + anggota + share', () {
    test('validateHouseholdName: kosong & >40 ditolak', () {
      expect(validateHouseholdName(''), 'Nama rumah tangga wajib diisi.');
      expect(validateHouseholdName('   '), 'Nama rumah tangga wajib diisi.');
      expect(
        validateHouseholdName(List.filled(41, 'A').join()),
        contains('Maksimal 40'),
      );
      expect(validateHouseholdName('Bramantara'), isNull);
      expect(validateHouseholdName('  Keluarga Besar Bramantara  '), isNull);
    });

    test('HouseholdMember: roleLabel + shownName', () {
      const owner = HouseholdMember(
        uid: 'u1',
        displayName: 'ReWin',
        email: 'a@b.c',
        role: 'owner',
      );
      expect(owner.isOwner, isTrue);
      expect(owner.roleLabel, 'Pengelola');
      expect(owner.shownName, 'ReWin');
      const member = HouseholdMember(uid: 'u2', email: 'm@x.id');
      expect(member.isOwner, isFalse);
      expect(member.roleLabel, 'Anggota');
      expect(member.shownName, 'm@x.id');
      const anon = HouseholdMember(uid: 'u3');
      expect(anon.shownName, 'Anggota');
    });

    test('inviteShareText: kode + nama + 24 jam + alur', () {
      final t = inviteShareText('ABCD-EFGH', 'Bramantara');
      expect(t, contains('ABCD-EFGH'));
      expect(t, contains('Bramantara'));
      expect(t, contains('24 jam'));
      expect(t, contains('Keluarga'));
      expect(inviteShareText('ABCD-EFGH', null), contains('Keluarga'));
    });

    test('unavailable → tanpa internet; deadline → sinyal lemot', () {
      expect(
        friendlyAuthError(Exception('[cloud_firestore/unavailable]')),
        contains('internet'),
      );
      // deadline = timeout handshake (WiFi nyala tapi zonk): pesan baru
      // suruh cari sinyal kuat, bukan "tidak ada internet".
      expect(
        friendlyAuthError(Exception('Deadline exceeded')),
        contains('sinyal kuat'),
      );
      expect(
        friendlyAuthError(Exception('[firebase_auth/unauthenticated]')),
        contains('kedaluwarsa'),
      );
    });
  });
}
