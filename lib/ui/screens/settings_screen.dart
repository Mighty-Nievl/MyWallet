import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/auth_service.dart';
import '../../data/settings.dart';
import '../app_theme.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import 'settings_about.dart';
import 'settings_appearance.dart';
import 'settings_family.dart';
import 'settings_manage.dart';
import 'settings_privacy.dart';

/// Hub Pengaturan (multi-page): 4 grup → tiap grup punya sub-halaman sendiri.
///
/// STEP 4 — hanya presentasi yang diubah. Navigasi TETAP:
/// Tampilan → [AppearanceSettingsPage], Saldo & Privasi →
/// [PrivacySettingsPage], Kelola → [ManageSettingsPage],
/// Tentang → [AboutSettingsPage]. Pencarian hub memfilter item
/// di semua grup; ketuk hasil untuk lompat ke sub-halaman
/// (query ikut diteruskan agar filter di sana langsung aktif).
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
    final family = ref.watch(familySessionProvider);
    final familySubtitle = family.when(
      loading: () => '…',
      error: (_, _) => 'Pribadi · offline',
      data: (s) => switch (s.status) {
        FamilyStatus.household =>
          s.householdName ?? 'Anggota rumah tangga',
        FamilyStatus.signedIn => s.email ?? 'Sudah masuk',
        _ => 'Pribadi · offline',
      },
    );

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
      _HubEntry('Keluarga', 'Catat bareng pasangan',
          const ['keluarga', 'family', 'sync', 'google', 'login'],
          _GroupKey.keluarga),
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
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: 'Pengaturan'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  96,
                ),
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
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  if (searching) ...[
                    Text(
                        'Hasil pencarian (${results.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                                fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.s8),
                    if (results.isEmpty)
                      const Card(
                        child: Padding(
                          padding: AppSpacing.cardPadding,
                          child: Text(
                              'Tidak ada pengaturan yang cocok.'),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < results.length;
                                i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, indent: 52),
                              SettingRow(
                                icon: _groupIcon(
                                    results[i].group),
                                title: results[i].title,
                                subtitle:
                                    '${results[i].subtitle} · ${_groupLabel(results[i].group)}',
                                onTap: () => _openGroup(
                                    results[i].group),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ] else ...[
                    Card(
                      child: Column(
                        children: [
                          SettingRow(
                            icon: Icons.palette_outlined,
                            title: 'Tampilan',
                            subtitle:
                                'Tema: $themeLabel · $accentLabel',
                            onTap: () =>
                                _openGroup(_GroupKey.tampilan),
                          ),
                          const Divider(height: 1, indent: 52),
                          SettingRow(
                            icon: Icons.shield_outlined,
                            title: 'Saldo & Privasi',
                            subtitle:
                                'Saldo awal · Kunci: $lockLabel',
                            onTap: () =>
                                _openGroup(_GroupKey.privasi),
                          ),
                          const Divider(height: 1, indent: 52),
                          SettingRow(
                            icon: Icons.folder_outlined,
                            title: 'Kelola',
                            subtitle: catCount == null
                                ? 'Kategori · backup · restore'
                                : '$catCount kategori · backup · restore',
                            onTap: () =>
                                _openGroup(_GroupKey.kelola),
                          ),
                          const Divider(height: 1, indent: 52),
                          SettingRow(
                            icon: Icons.group_outlined,
                            title: 'Keluarga',
                            subtitle:
                                'Catat bareng · $familySubtitle',
                            onTap: () =>
                                _openGroup(_GroupKey.keluarga),
                          ),
                          const Divider(height: 1, indent: 52),
                          SettingRow(
                            icon: Icons.info_outlined,
                            title: 'Tentang',
                            subtitle: 'Versi · changelog',
                            onTap: () =>
                                _openGroup(_GroupKey.tentang),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroup(_GroupKey group) {
    final q = _searchCtrl.text;
    final page = switch (group) {
      _GroupKey.tampilan => AppearanceSettingsPage(initialQuery: q),
      _GroupKey.privasi => PrivacySettingsPage(initialQuery: q),
      _GroupKey.kelola => ManageSettingsPage(initialQuery: q),
      _GroupKey.keluarga => const FamilySettingsPage(),
      _GroupKey.tentang => const AboutSettingsPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

enum _GroupKey { tampilan, privasi, kelola, keluarga, tentang }

String _groupLabel(_GroupKey g) => switch (g) {
      _GroupKey.tampilan => 'Tampilan',
      _GroupKey.privasi => 'Saldo & Privasi',
      _GroupKey.kelola => 'Kelola',
      _GroupKey.keluarga => 'Keluarga',
      _GroupKey.tentang => 'Tentang',
    };

IconData _groupIcon(_GroupKey g) => switch (g) {
      _GroupKey.tampilan => Icons.palette_outlined,
      _GroupKey.privasi => Icons.shield_outlined,
      _GroupKey.kelola => Icons.folder_outlined,
      _GroupKey.keluarga => Icons.group_outlined,
      _GroupKey.tentang => Icons.info_outlined,
    };

class _HubEntry {
  const _HubEntry(this.title, this.subtitle, this.keys, this.group);
  final String title;
  final String subtitle;
  final List<String> keys;
  final _GroupKey group;
}
