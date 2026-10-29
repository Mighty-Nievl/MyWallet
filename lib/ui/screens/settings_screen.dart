import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';
import '../app_theme.dart';
import '../components/setting_row.dart';
import '../components/settings_scaffold.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'settings_about.dart';
import 'settings_appearance.dart';
import 'settings_catalog.dart';
import 'settings_manage.dart';
import 'settings_privacy.dart';

/// Hub Pengaturan (multi-page): 4 grup → tiap grup punya sub-halaman sendiri.
///
/// v1.27: Keluarga KELUAR dari hub — pindah ke pohon akun
/// Beranda → Profil → Keluarga. Hub tinggal Tampilan, Saldo & Privasi,
/// Kelola, Tentang.
///
/// v1.43.0: pencarian TIDAK lagi memakai daftar hardcoded terpisah.
/// Sumbernya [SettingsCatalog.all] — daftar yang sama yang dipakai filter
/// di tiap sub-halaman, jadi tidak ada lagi baris yang bisa dicari di satu
/// tempat tapi tidak ada di tempat lain (dulu 7 baris begitu).
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
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final accent = ref.watch(accentColorProvider).value;
    final appLock = ref.watch(appLockProvider).value ?? 'none';
    final catCount = ref.watch(categoriesProvider).value?.length;

    final themeLabel = switch (themeMode) {
      ThemeMode.light => 'Terang',
      ThemeMode.dark => 'Gelap',
      ThemeMode.system => 'Ikuti HP',
    };
    final accentLabel = accent == null
        ? ''
        : (AppTheme.accentOptions[accent]?.label ?? accent);
    final lockLabel = switch (appLock) {
      'pin' => 'PIN',
      'biometric' => 'Biometrik',
      _ => 'Mati',
    };

    final searching = _q.isNotEmpty;
    final results = searching
        ? SettingsCatalog.all.where((e) => e.matches(_q)).toList()
        : const <SettingsEntry>[];

    return SettingsScaffold(
      title: 'Pengaturan',
      search: SettingsSearchField(
        controller: _searchCtrl,
        hint: 'Cari pengaturan… (cth. font, backup)',
        query: _q,
        onChanged: (v) => setState(() => _q = v),
      ),
      children: [
        if (searching)
          if (results.isEmpty)
            // v1.45: empty state tidak boleh buntu. Dulu cuma "tidak ada
            // yang cocok" — user tak tahu harus mengetik apa. Sekarang:
            // contoh kata kunci + jalan keluar satu tap.
            Card(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tidak ada pengaturan yang cocok.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Coba kata lain: tema, backup, kategori, atau kunci.',
                      style: AppType.secondary(context),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                        child: const Text('Bersihkan pencarian'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SettingsGroup(
              title: 'Hasil pencarian (${results.length})',
              children: [
                for (final e in results)
                  SettingRow(
                    icon: settingsGroupIcon(e.group),
                    title: e.title,
                    subtitle: '${e.subtitle} · ${settingsGroupLabel(e.group)}',
                    onTap: () => _openGroup(e.group),
                  ),
              ],
            )
        else
          SettingsGroup(
            title: 'Semua pengaturan',
            children: [
              SettingRow(
                icon: Icons.palette_outlined,
                title: 'Tampilan',
                subtitle: 'Tema: $themeLabel · $accentLabel',
                onTap: () => _openGroup(SettingsGroupId.tampilan),
              ),
              SettingRow(
                icon: Icons.shield_outlined,
                // v1.36.1: pengingat tinggal di halaman ini, jadi namanya
                // jujur (dulu cuma Saldo & Privasi).
                title: 'Saldo, Privasi & Pengingat',
                subtitle: 'Saldo awal · Kunci: $lockLabel · Pengingat',
                onTap: () => _openGroup(SettingsGroupId.privasi),
              ),
              SettingRow(
                icon: Icons.folder_outlined,
                title: 'Kelola',
                subtitle: catCount == null
                    ? 'Kategori · backup · restore'
                    : '$catCount kategori · backup · restore',
                onTap: () => _openGroup(SettingsGroupId.kelola),
              ),
              SettingRow(
                icon: Icons.info_outlined,
                title: 'Tentang',
                subtitle: 'Versi · changelog',
                onTap: () => _openGroup(SettingsGroupId.tentang),
              ),
            ],
          ),
      ],
    );
  }

  void _openGroup(SettingsGroupId group) {
    final q = _searchCtrl.text;
    final page = switch (group) {
      SettingsGroupId.tampilan => AppearanceSettingsPage(initialQuery: q),
      SettingsGroupId.privasi => PrivacySettingsPage(initialQuery: q),
      SettingsGroupId.kelola => ManageSettingsPage(initialQuery: q),
      SettingsGroupId.tentang => const AboutSettingsPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
