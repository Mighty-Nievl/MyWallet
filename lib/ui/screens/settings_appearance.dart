import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../app_theme.dart';
import '../components/setting_row.dart';
import '../components/settings_scaffold.dart';
import '../design/app_spacing.dart';
import 'settings_actions.dart';
import 'settings_catalog.dart';

/// Sub-halaman Tampilan: tema, aksen, wallpaper, hitam pekat, font,
/// nominal ringkas + sub-bagian Isi Beranda + List & tanggal.
///
/// v1.43.0: kerangka dari [SettingsScaffold], switch dari [SettingSwitch],
/// dan filter cari dari [SettingsCatalog] — bukan string yang disalin.
class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key, this.initialQuery = ''});

  /// Query awal dari pencarian di hub (biar filter ikut kebawa).
  final String initialQuery;

  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends ConsumerState<AppearanceSettingsPage>
    with SettingsActions {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _q = widget.initialQuery.trim().toLowerCase();
    if (_q.isNotEmpty) _searchCtrl.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _show(String id) => SettingsCatalog.byId(id).matches(_q);

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final useDynamic = ref.watch(useDynamicColorProvider);
    final trueBlack = ref.watch(trueBlackProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final compactAmounts = ref.watch(compactAmountsProvider);
    final showTop = ref.watch(showTopCategoriesProvider);
    final showDaily = ref.watch(showDailyTotalsProvider);
    final displayName = ref.watch(displayNameProvider);
    final showRecent = ref.watch(showRecentProvider);
    final recentCount = ref.watch(recentCountProvider);
    final compactList = ref.watch(compactListProvider);
    final relativeDates = ref.watch(relativeDatesProvider);
    final showIcons = ref.watch(showCategoryIconsProvider);
    final service = ref.read(settingsServiceProvider);

    String themeLabel(ThemeMode m) => switch (m) {
      ThemeMode.light => 'Terang',
      ThemeMode.dark => 'Gelap',
      ThemeMode.system => 'Ikuti HP',
    };
    String accentLabel() {
      final a = accent.value;
      if (a == null) return '…';
      return AppTheme.accentOptions[a]?.label ?? a;
    }

    return SettingsScaffold(
      title: 'Tampilan',
      search: SettingsSearchField(
        controller: _searchCtrl,
        hint: 'Cari di Tampilan…',
        query: _q,
        onChanged: (v) => setState(() => _q = v),
      ),
      children: [
        SettingsGroup(
          title: 'Warna & tema',
          children: [
            if (_show('tema'))
              SettingRow(
                icon: Icons.brightness_auto_outlined,
                title: 'Tema',
                subtitle: themeLabel(themeMode.value ?? ThemeMode.system),
                trailing: SettingValue(
                  value: themeLabel(themeMode.value ?? ThemeMode.system),
                ),
                onTap: pickTheme,
              ),
            if (_show('aksen'))
              SettingRow(
                icon: Icons.palette_outlined,
                title: 'Warna aksen',
                subtitle: accentLabel(),
                trailing: accent.value == null
                    ? const SizedBox.shrink()
                    : CircleAvatar(
                        backgroundColor: AppTheme.seedFor(accent.value!),
                        radius: 12,
                      ),
                onTap: () => pickAccent(AppTheme.accentOptions),
              ),
            if (_show('wallpaper'))
              SettingSwitch(
                icon: Icons.wallpaper_outlined,
                title: 'Ikuti warna wallpaper HP',
                subtitle:
                    'Material You — Android 12 ke atas, menimpa warna aksen',
                value: useDynamic.value ?? false,
                onChanged: service.setUseDynamicColor,
              ),
            if (_show('hitam'))
              SettingSwitch(
                icon: Icons.dark_mode_outlined,
                title: 'Hitam pekat',
                subtitle: 'Background hitam total di mode gelap (hemat OLED)',
                value: trueBlack.value ?? false,
                onChanged: service.setTrueBlack,
              ),
            if (_show('font'))
              SettingRow(
                icon: Icons.format_size,
                title: 'Ukuran font',
                subtitle: fontScale.value == null
                    ? '…'
                    : fontScaleLabel(fontScale.value!),
                trailing: SettingValue(
                  value: fontScale.value == null
                      ? '…'
                      : fontScaleLabel(fontScale.value!),
                ),
                onTap: pickFontScale,
              ),
            if (_show('nominal-ringkas'))
              SettingSwitch(
                icon: Icons.short_text,
                title: 'Nominal ringkas',
                subtitle: (compactAmounts.value ?? false)
                    ? 'Contoh: Rp1,5 jt'
                    : 'Contoh: Rp1.500.000',
                value: compactAmounts.value ?? false,
                onChanged: service.setCompactAmounts,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SettingsGroup(
          title: 'Isi Beranda',
          children: [
            if (_show('nama-sapaan'))
              SettingRow(
                icon: Icons.waving_hand_outlined,
                title: 'Nama sapaan',
                subtitle: 'Sapaan di Beranda, mis. “Selamat pagi, ReWin”',
                trailing: SettingValue(
                  value: switch (displayName.value) {
                    null => '…',
                    '' => 'Ikut akun',
                    final n => n,
                  },
                ),
                onTap: editDisplayName,
              ),
            if (_show('ringkasan-harian'))
              SettingSwitch(
                icon: Icons.today_outlined,
                title: 'Ringkasan hari ini',
                subtitle: 'Masuk / keluar / selisih tanggal hari ini',
                value: showDaily.value ?? true,
                onChanged: service.setShowDailyTotals,
              ),
            if (_show('top-kategori'))
              SettingSwitch(
                icon: Icons.category_outlined,
                title: 'Top kategori bulan ini',
                subtitle: 'Bar pengeluaran per kategori di Beranda',
                value: showTop.value ?? true,
                onChanged: service.setShowTopCategories,
              ),
            if (_show('terakhir-dicatat'))
              SettingSwitch(
                icon: Icons.history,
                title: 'Terakhir dicatat',
                subtitle: recentCount.value == null
                    ? '…'
                    : 'Tampilkan ${recentCount.value} transaksi terakhir',
                value: showRecent.value ?? true,
                onChanged: service.setShowRecent,
              ),
            if ((showRecent.value ?? true) && _show('jumlah-ditampilkan'))
              SettingRow(
                icon: Icons.format_list_numbered,
                title: 'Jumlah ditampilkan',
                subtitle: recentCount.value == null
                    ? '…'
                    : '${recentCount.value} transaksi',
                trailing: SettingValue(
                  value: recentCount.value == null
                      ? '…'
                      : '${recentCount.value}',
                ),
                onTap: pickRecentCount,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SettingsGroup(
          title: 'List & tanggal',
          children: [
            if (_show('list-rapat'))
              SettingSwitch(
                icon: Icons.density_small_outlined,
                title: 'List rapat',
                subtitle: 'Baris transaksi lebih padat, muat lebih banyak',
                value: compactList.value ?? false,
                onChanged: service.setCompactList,
              ),
            if (_show('tanggal-relatif'))
              SettingSwitch(
                icon: Icons.today_outlined,
                title: 'Tanggal relatif',
                subtitle: '"Hari ini / Kemarin" gantikan tanggal penuh di list',
                value: relativeDates.value ?? true,
                onChanged: service.setRelativeDates,
              ),
            if (_show('ikon-kategori'))
              SettingSwitch(
                icon: Icons.emoji_emotions_outlined,
                title: 'Ikon kategori',
                subtitle: 'Emoji di tiap baris transaksi & laporan',
                value: showIcons.value ?? true,
                onChanged: service.setShowCategoryIcons,
              ),
          ],
        ),
      ],
    );
  }
}
