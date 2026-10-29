import 'package:flutter/material.dart';

/// Katalog setelan — SATU daftar untuk semua yang bisa dicari & dituju.
///
/// Kenapa ada: dulu hub punya `_HubEntry` hardcoded (25 entri) sementara
/// halaman-halamannya berisi 32 baris. Salinan manual itu sudah drift —
/// "Nama sapaan", "Export PDF laporan", "Backup otomatis", "Backup
/// terakhir", "Pulihkan backup otomatis", "Jumlah ditampilkan" dan "Jam
/// pengingat" tidak bisa ditemukan dari pencarian hub. Sekarang hub
/// membaca daftar ini, dan `test/settings_catalog_test.dart` memastikan
/// tiap entri benar-benar ada di halamannya (dan sebaliknya).
///
/// Aturan pakai: setiap `SettingRow`/`SettingSwitch` di halaman
/// pengaturan WAJIB punya entri di sini, dan filter cari halaman memakai
/// [SettingsEntry.matches] — bukan string terpisah.
enum SettingsGroupId { tampilan, privasi, kelola, tentang }

class SettingsEntry {
  const SettingsEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.keys,
    required this.group,
    this.dynamicTitle = false,
  });

  /// Kunci stabil untuk `_show('tema')` di halaman.
  final String id;
  final String title;
  final String subtitle;

  /// Sinonim tambahan (Indonesia + Inggris) untuk pencarian.
  final List<String> keys;
  final SettingsGroupId group;

  /// Judul dirakit runtime (mis. "MyWallet v1.43.0 (93)") — tidak bisa
  /// dicocokkan sebagai literal oleh test katalog.
  final bool dynamicTitle;

  bool matches(String q) {
    if (q.isEmpty) return true;
    return '${title.toLowerCase()} ${subtitle.toLowerCase()} '
            '${keys.join(' ').toLowerCase()}'
        .contains(q);
  }
}

String settingsGroupLabel(SettingsGroupId g) => switch (g) {
  SettingsGroupId.tampilan => 'Tampilan',
  SettingsGroupId.privasi => 'Saldo, Privasi & Pengingat',
  SettingsGroupId.kelola => 'Kelola',
  SettingsGroupId.tentang => 'Tentang',
};

IconData settingsGroupIcon(SettingsGroupId g) => switch (g) {
  SettingsGroupId.tampilan => Icons.palette_outlined,
  SettingsGroupId.privasi => Icons.shield_outlined,
  SettingsGroupId.kelola => Icons.folder_outlined,
  SettingsGroupId.tentang => Icons.info_outlined,
};

abstract final class SettingsCatalog {
  static const all = <SettingsEntry>[
    // ---------- Tampilan ----------
    SettingsEntry(
      id: 'tema',
      title: 'Tema',
      subtitle: 'Terang / Gelap / Ikuti HP',
      keys: ['theme', 'dark', 'light', 'gelap', 'terang'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'aksen',
      title: 'Warna aksen',
      subtitle: 'Hijau, biru, ungu, oranye…',
      keys: ['accent', 'color', 'warna', 'palette'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'wallpaper',
      title: 'Ikuti warna wallpaper HP',
      subtitle: 'Material You Android 12+',
      keys: ['dynamic', 'wallpaper', 'material'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'hitam',
      title: 'Hitam pekat',
      subtitle: 'Hemat OLED mode gelap',
      keys: ['black', 'amoled', 'hitam'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'font',
      title: 'Ukuran font',
      subtitle: 'Kecil – Sangat besar',
      keys: ['font', 'huruf', 'ukuran'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'nominal-ringkas',
      title: 'Nominal ringkas',
      subtitle: 'Rp1,5 jt vs Rp1.500.000',
      keys: ['compact', 'rp', 'jt', 'ringkas'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'nama-sapaan',
      title: 'Nama sapaan',
      subtitle: 'Sapaan di Beranda, mis. “Selamat pagi, ReWin”',
      keys: ['nama', 'name', 'sapa', 'sapaan'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'ringkasan-harian',
      title: 'Ringkasan hari ini',
      subtitle: 'Masuk / keluar / selisih hari ini',
      keys: ['daily', 'hari', 'harian'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'top-kategori',
      title: 'Top kategori bulan ini',
      subtitle: 'Bar pengeluaran per kategori di Beranda',
      keys: ['category', 'top', 'kategori'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'terakhir-dicatat',
      title: 'Terakhir dicatat',
      subtitle: '3 / 5 / 10 transaksi',
      keys: ['recent', 'riwayat', 'terakhir'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'jumlah-ditampilkan',
      title: 'Jumlah ditampilkan',
      subtitle: 'Berapa transaksi terakhir yang tampil',
      keys: ['jumlah', 'recent', 'count'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'list-rapat',
      title: 'List rapat',
      subtitle: 'Baris lebih padat, muat lebih banyak',
      keys: ['dense', 'padat', 'rapat'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'tanggal-relatif',
      title: 'Tanggal relatif',
      subtitle: '"Hari ini / Kemarin" gantikan tanggal penuh',
      keys: ['date', 'tanggal', 'relatif'],
      group: SettingsGroupId.tampilan,
    ),
    SettingsEntry(
      id: 'ikon-kategori',
      title: 'Ikon kategori',
      subtitle: 'Emoji di tiap baris transaksi & laporan',
      keys: ['icon', 'emoji', 'ikon'],
      group: SettingsGroupId.tampilan,
    ),

    // ---------- Saldo, Privasi & Pengingat ----------
    SettingsEntry(
      id: 'sembunyikan-saldo',
      title: 'Sembunyikan saldo',
      subtitle: 'Nominal jadi Rp••••',
      keys: ['hide', 'privacy', 'sembunyi'],
      group: SettingsGroupId.privasi,
    ),
    SettingsEntry(
      id: 'cakupan',
      title: 'Cakupan sembunyikan',
      subtitle: 'Saldo saja / semua nominal',
      keys: ['scope', 'cakupan', 'semua'],
      group: SettingsGroupId.privasi,
    ),
    SettingsEntry(
      id: 'saldo-awal',
      title: 'Saldo awal',
      subtitle: 'Uang sebelum mencatat',
      keys: ['balance', 'awal', 'saldo'],
      group: SettingsGroupId.privasi,
    ),
    SettingsEntry(
      id: 'kunci-aplikasi',
      title: 'Kunci aplikasi',
      subtitle: 'PIN / biometrik',
      keys: ['lock', 'pin', 'biometric', 'kunci'],
      group: SettingsGroupId.privasi,
    ),
    SettingsEntry(
      id: 'pengingat',
      title: 'Ingatkan mencatat',
      subtitle: 'Notifikasi harian',
      keys: ['reminder', 'notifikasi', 'ingat', 'pengingat'],
      group: SettingsGroupId.privasi,
    ),
    SettingsEntry(
      id: 'jam-pengingat',
      title: 'Jam pengingat',
      subtitle: 'Waktu notifikasi harian',
      keys: ['jam', 'time', 'waktu'],
      group: SettingsGroupId.privasi,
    ),

    // ---------- Kelola ----------
    SettingsEntry(
      id: 'kelola-kategori',
      title: 'Kelola kategori',
      subtitle: 'Tambah / hapus',
      keys: ['category', 'kategori'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'export-csv',
      title: 'Export CSV',
      subtitle: 'Semua transaksi sebagai file CSV',
      keys: ['export', 'csv', 'spreadsheet'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'export-pdf',
      title: 'Export PDF laporan',
      subtitle: 'Ringkasan + rincian bulan aktif',
      keys: ['pdf', 'laporan', 'export'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'backup-db',
      title: 'Backup database',
      subtitle: 'Simpan salinan mywallet.sqlite ke file',
      keys: ['backup', 'salinan'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'backup-otomatis',
      title: 'Backup otomatis',
      subtitle: 'Tiap hari, 5 salinan terakhir di HP',
      keys: ['auto', 'otomatis', 'harian'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'backup-terakhir',
      title: 'Backup terakhir',
      subtitle: 'Kapan terakhir data disalin',
      keys: ['terakhir', 'last', 'kapan'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'pulihkan-auto',
      title: 'Pulihkan backup otomatis',
      subtitle: 'Pilih salinan harian yang tersimpan di HP',
      keys: ['pulihkan', 'restore', 'auto'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'restore-db',
      title: 'Restore database',
      subtitle: 'Hati-hati: menimpa SEMUA data sekarang',
      keys: ['restore', 'kembalikan'],
      group: SettingsGroupId.kelola,
    ),
    SettingsEntry(
      id: 'hapus-data',
      title: 'Hapus semua data',
      subtitle: 'Reset total — transaksi, kategori, budget hilang',
      keys: ['delete', 'wipe', 'hapus', 'reset'],
      group: SettingsGroupId.kelola,
    ),

    // ---------- Tentang ----------
    SettingsEntry(
      id: 'versi',
      title: 'MyWallet',
      subtitle: 'Info versi aplikasi',
      keys: ['versi', 'version', 'about'],
      group: SettingsGroupId.tentang,
      dynamicTitle: true,
    ),
    SettingsEntry(
      id: 'changelog',
      title: 'Changelog',
      subtitle: 'Riwayat perubahan versi',
      keys: ['changelog', 'riwayat', 'versi'],
      group: SettingsGroupId.tentang,
    ),
  ];

  static final Map<String, SettingsEntry> _byId = {
    for (final e in all) e.id: e,
  };

  /// Entri untuk `_show('tema')` di halaman — salah ketik id = error
  /// keras saat build, bukan baris yang diam-diam hilang.
  static SettingsEntry byId(String id) {
    final e = _byId[id];
    if (e == null) throw StateError('Setelan "$id" tidak ada di katalog.');
    return e;
  }

  static List<SettingsEntry> inGroup(SettingsGroupId g) =>
      all.where((e) => e.group == g).toList(growable: false);
}
