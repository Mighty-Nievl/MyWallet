import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';
import '../app_theme.dart';
import 'settings_about.dart';
import 'settings_appearance.dart';
import 'settings_manage.dart';
import 'settings_privacy.dart';

/// Hub Pengaturan (multi-page): 4 grup → tiap grup punya sub-halaman sendiri.
/// User pilih grup yang mau dibuka, tidak perlu scroll satu halaman panjang.
///
/// - Tampilan → [AppearanceSettingsPage]
/// - Saldo & Privasi → [PrivacySettingsPage]
/// - Kelola → [ManageSettingsPage]
/// - Tentang → [AboutSettingsPage]
///
/// Kolom cari di hub memfilter item di semua grup; ketuk hasil
/// untuk langsung lompat ke sub-halaman terkait (query ikut diteruskan
/// agar filter di sana langsung aktif).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final appLock = ref.watch(appLockProvider);
    final cats = ref.watch(categoriesProvider);

    final themeLabel = themeMode.when(
      loading: () => '…',
      error: (_, _) => '…',
      data: (m) => switch (m) {
        ThemeMode.light => 'Terang',
        ThemeMode.dark => 'Gelap',
        ThemeMode.system => 'Ikuti HP',
      },
    );
    final accentLabel = accent.when(
      loading: () => '',
      error: (_, _) => '',
      data: (a) => AppTheme.accentOptions[a]?.label ?? a,
    );
    final lockLabel = appLock.when(
      loading: () => '…',
      error: (_, _) => '…',
      data: (m) => switch (m) {
        'pin' => 'PIN',
        'biometric' => 'Biometrik',
        _ => 'Mati',
      },
    );
    final catCount = cats.when(
      loading: () => null,
      error: (_, _) => null,
      data: (list) => list.length,
    );

    // Semua item yang bisa dicari: judul + deskripsi + kunci + tujuan.
    final items = <_HubEntry>[
      _HubEntry('Tema', 'Terang / Gelap / Ikuti HP', const ['theme', 'dark', 'light'],
          _GroupKey.tampilan),
      _HubEntry('Warna aksen', 'Hijau, biru, ungu, oranye…', const ['accent', 'color', 'palette'],
          _GroupKey.tampilan),
      _HubEntry('Ikuti warna wallpaper HP', 'Material You Android 12+', const ['dynamic', 'wallpaper'],
          _GroupKey.tampilan),
      _HubEntry('Hitam pekat', 'Hemat OLED mode gelap', const ['black', 'amoled'],
          _GroupKey.tampilan),
      _HubEntry('Ukuran font', 'Kecil – Sangat besar', const ['font', 'huruf'],
          _GroupKey.tampilan),
      _HubEntry('Nominal ringkas', 'Rp1,5 jt vs Rp1.500.000', const ['compact', 'rp', 'jt'],
          _GroupKey.tampilan),
      _HubEntry('Ringkasan hari ini', 'Masuk / keluar hari ini', const ['daily', 'hari'],
          _GroupKey.tampilan),
      _HubEntry('Ringkasan masuk / keluar', 'Angka bulanan di saldo', const ['home', 'bulan'],
          _GroupKey.tampilan),
      _HubEntry('Top kategori', 'Bar pengeluaran Beranda', const ['category', 'top'],
          _GroupKey.tampilan),
      _HubEntry('Terakhir dicatat', '3 / 5 / 10 transaksi', const ['recent', 'riwayat'],
          _GroupKey.tampilan),
      _HubEntry('List rapat', 'Baris lebih padat', const ['dense', 'padat'],
          _GroupKey.tampilan),
      _HubEntry('Tanggal relatif', 'Hari ini / Kemarin', const ['date', 'tanggal'],
          _GroupKey.tampilan),
      _HubEntry('Ikon kategori', 'Emoji di list', const ['icon', 'emoji'],
          _GroupKey.tampilan),
      _HubEntry('Sembunyikan saldo', 'Jadi Rp••••', const ['hide', 'privacy'],
          _GroupKey.privasi),
      _HubEntry('Cakupan sembunyikan', 'Saldo saja / semua', const ['scope'],
          _GroupKey.privasi),
      _HubEntry('Saldo awal', 'Uang sebelum mencatat', const ['balance', 'awal'],
          _GroupKey.privasi),
      _HubEntry('Kunci aplikasi', 'PIN / biometrik', const ['lock', 'pin', 'biometric', 'kunci'],
          _GroupKey.privasi),
      _HubEntry('Pengingat harian', 'Notifikasi catat', const ['reminder', 'notifikasi', 'jam'],
          _GroupKey.privasi),
      _HubEntry('Kelola kategori', 'Tambah / hapus', const ['category', 'kategori'],
          _GroupKey.kelola),
      _HubEntry('Export CSV', 'File spreadsheet', const ['export', 'csv'],
          _GroupKey.kelola),
      _HubEntry('Backup database', 'Salinan sqlite', const ['backup'],
          _GroupKey.kelola),
      _HubEntry('Restore database', 'Timpa dari backup', const ['restore'],
          _GroupKey.kelola),
      _HubEntry('Hapus semua data', 'Reset total', const ['delete', 'wipe', 'hapus'],
          _GroupKey.kelola),
      _HubEntry('Tentang', 'Versi + changelog', const ['about', 'version', 'versi'],
          _GroupKey.tentang),
    ];

    final searching = _q.isNotEmpty;
    final results = searching
        ? items.where((e) {
            final hay = '${e.title} ${e.subtitle} ${e.keys.join(' ')}'.toLowerCase();
            return hay.contains(_q);
          }).toList()
        : <_HubEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari pengaturan… (cth. font, backup)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searching
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _q = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          if (searching) ...[
            Text('Hasil pencarian (${results.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tidak ada pengaturan yang cocok.'),
                ),
              ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < results.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(_groupIcon(results[i].group)),
                      title: Text(results[i].title),
                      subtitle: Text(
                          '${results[i].subtitle} · ${_groupLabel(results[i].group)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openGroup(results[i].group),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Tampilan'),
                    subtitle: Text('Tema: $themeLabel · $accentLabel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openGroup(_GroupKey.tampilan),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield),
                    title: const Text('Saldo & Privasi'),
                    subtitle: Text('Saldo awal · Kunci: $lockLabel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openGroup(_GroupKey.privasi),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('Kelola'),
                    subtitle: Text(catCount == null
                        ? 'Kategori · backup · restore'
                        : '$catCount kategori · backup · restore'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openGroup(_GroupKey.kelola),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Tentang'),
                    subtitle: const Text('Versi · changelog'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openGroup(_GroupKey.tentang),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _openGroup(_GroupKey group) {
    final q = _searchCtrl.text;
    final page = switch (group) {
      _GroupKey.tampilan => AppearanceSettingsPage(initialQuery: q),
      _GroupKey.privasi => PrivacySettingsPage(initialQuery: q),
      _GroupKey.kelola => ManageSettingsPage(initialQuery: q),
      _GroupKey.tentang => const AboutSettingsPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

enum _GroupKey { tampilan, privasi, kelola, tentang }

String _groupLabel(_GroupKey g) => switch (g) {
      _GroupKey.tampilan => 'Tampilan',
      _GroupKey.privasi => 'Saldo & Privasi',
      _GroupKey.kelola => 'Kelola',
      _GroupKey.tentang => 'Tentang',
    };

IconData _groupIcon(_GroupKey g) => switch (g) {
      _GroupKey.tampilan => Icons.palette,
      _GroupKey.privasi => Icons.shield,
      _GroupKey.kelola => Icons.folder,
      _GroupKey.tentang => Icons.info,
    };

class _HubEntry {
  const _HubEntry(this.title, this.subtitle, this.keys, this.group);
  final String title;
  final String subtitle;
  final List<String> keys;
  final _GroupKey group;
}
