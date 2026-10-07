import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mywallet/ui/changelog.dart';

/// Pengaman: tiap naik `version:` di pubspec WAJIB tambah entri
/// changelog baru di `lib/ui/changelog.dart`.
///
/// Tanpa ini changelog in-app gampang ketinggalan (kejadian: v1.4.0–v1.8.x
/// tidak muncul di dialog Tentang). Test ini gagal dengan pesan jelas
/// bila entri teratas beda dengan versi pubspec.
void main() {
  test('entri changelog teratas cocok dengan version pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull, reason: 'version: tidak ketemu di pubspec.yaml');
    final expected = 'v${m!.group(1)}';
    expect(appChangelog, isNotEmpty);
    expect(
      appChangelog.first.version,
      expected,
      reason: 'Naik versi ke $expected tapi lib/ui/changelog.dart belum '
          'ditambah entri baru paling atas. Tambah dulu, lalu update '
          'docs/07-Rilis-dan-Obtainium.md + README.',
    );
  });

  test('format changelog rapi + urutan terbaru dulu', () {
    final text = formatChangelog();
    expect(text, contains(appChangelog.first.version));
    expect(text, contains(appChangelog.last.version));
    // Tiap entri versi unik, tidak ada duplikat.
    final versions = appChangelog.map((e) => e.version).toList();
    expect(versions.toSet(), hasLength(versions.length));
  });
}
