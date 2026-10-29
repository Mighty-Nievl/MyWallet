// Kontrak Pengaturan — mengunci dua hal yang dulu bolong:
//
// 1. SETIAP provider setelan punya konsumen di luar `data/settings.dart`.
//    `showMonthTotalsProvider` dulu hanya dibaca baris switch-nya sendiri:
//    user mengubah, tak terjadi apa pun, dan tak ada tes yang menangkapnya.
//
// 2. SETIAP baris di halaman pengaturan punya entri katalog, dan setiap
//    entri katalog benar-benar ada di halaman. Dulu hub punya 25 entri
//    hardcoded untuk 32 baris nyata → 7 setelan tak bisa dicari.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/ui/screens/settings_catalog.dart';

/// Provider infrastruktur, bukan setelan user.
const _infra = {'prefsProvider', 'settingsServiceProvider', 'unlockedProvider'};

/// Judul grup (SettingsGroup) & judul halaman (SettingsScaffold), bukan
/// baris setelan.
const _groupTitles = {
  // SettingsScaffold
  'Tampilan',
  'Saldo, Privasi & Pengingat',
  'Kelola',
  'Tentang',
  // SettingsGroup
  'Warna & tema',
  'Isi Beranda',
  'List & tanggal',
  'Saldo',
  'Keamanan',
  'Pengingat',
  'Data',
  'Zona berbahaya',
  'Aplikasi',
  'Semua pengaturan',
};

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('setiap provider setelan dibaca di luar data/settings.dart', () {
    final source = File('lib/data/settings.dart').readAsStringSync();
    final names = RegExp(r'^final (\w+Provider)\s*=', multiLine: true)
        .allMatches(source)
        .map((m) => m.group(1)!)
        .where((n) => !_infra.contains(n))
        .toList();

    expect(names, isNotEmpty, reason: 'parser provider rusak?');

    final others = _dartFiles('lib')
        .where((f) => !f.path.endsWith('data/settings.dart'))
        .map((f) => f.readAsStringSync())
        .toList();

    final orphans = <String>[
      for (final n in names)
        if (!others.any((src) => src.contains(n))) n,
    ];

    expect(
      orphans,
      isEmpty,
      reason:
          'Provider ini cuma dipakai halaman setelannya sendiri — '
          'artinya toggle-nya tidak mengubah apa pun di aplikasi: $orphans',
    );
  });

  test('katalog: id unik, grup valid, semua punya kata kunci', () {
    final ids = SettingsCatalog.all.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id katalog duplikat');

    for (final e in SettingsCatalog.all) {
      expect(e.keys, isNotEmpty, reason: '${e.id} tanpa kata kunci');
      expect(e.title, isNotEmpty);
      expect(e.subtitle, isNotEmpty);
    }

    // 4 grup harus terisi — grup kosong = halaman yang tak bisa dicari.
    for (final g in SettingsGroupId.values) {
      expect(
        SettingsCatalog.inGroup(g),
        isNotEmpty,
        reason: 'grup ${g.name} tidak punya entri katalog',
      );
    }
  });

  test('katalog ↔ halaman: tidak ada baris liar, tidak ada entri hantu', () {
    const pages = {
      'Tampilan': 'lib/ui/screens/settings_appearance.dart',
      'Privasi': 'lib/ui/screens/settings_privacy.dart',
      'Kelola': 'lib/ui/screens/settings_manage.dart',
      'Tentang': 'lib/ui/screens/settings_about.dart',
    };

    final literalTitles = <String>{};
    // `\b` penting: tanpa itu `title:` juga menangkap `subtitle:`.
    final re = RegExp(r"\btitle: '([^']+)'");
    for (final entry in pages.entries) {
      final src = File(entry.value).readAsStringSync();
      for (final m in re.allMatches(src)) {
        final t = m.group(1)!;
        if (_groupTitles.contains(t)) continue;
        literalTitles.add(t);
      }
    }

    final catalogTitles = SettingsCatalog.all
        .where((e) => !e.dynamicTitle)
        .map((e) => e.title)
        .toSet();

    // Baris di halaman tapi tidak ada di katalog = tak bisa dicari dari hub.
    expect(
      literalTitles.difference(catalogTitles),
      isEmpty,
      reason: 'baris pengaturan tanpa entri katalog',
    );
    // Entri katalog tapi barisnya sudah dihapus/di-rename = hasil pencarian
    // menuju halaman yang tidak punya baris itu.
    expect(
      catalogTitles.difference(literalTitles),
      isEmpty,
      reason: 'entri katalog tanpa baris di halaman',
    );
  });

  test('katalog memuat 7 setelan yang dulu hilang dari pencarian hub', () {
    const duluHilang = [
      'Nama sapaan',
      'Jumlah ditampilkan',
      'Export PDF laporan',
      'Backup otomatis',
      'Backup terakhir',
      'Pulihkan backup otomatis',
      'Jam pengingat',
    ];
    final titles = SettingsCatalog.all.map((e) => e.title).toSet();
    for (final t in duluHilang) {
      expect(titles, contains(t), reason: '"$t" harus bisa dicari');
      // dan pencarian dengan kata kunci pendek harus menemukannya
      final q = t.toLowerCase().split(' ').first;
      expect(
        SettingsCatalog.all.any((e) => e.matches(q)),
        isTrue,
        reason: 'query "$q" tidak menemukan apa pun',
      );
    }
  });
}
