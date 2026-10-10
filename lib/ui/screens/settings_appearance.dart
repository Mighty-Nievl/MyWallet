import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../app_theme.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import 'settings_actions.dart';

/// Sub-halaman Tampilan: tema, aksen, wallpaper, hitam pekat, font,
/// nominal ringkas + sub-bagian Isi Beranda + List & tanggal.
///
/// STEP 4 — hanya presentasi yang diubah. Semua provider, setter,
/// dialog (via [SettingsActions]), filter cari, dan nilai TETAP.
class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key, this.initialQuery = ''});

  /// Query awal dari pencarian di hub (biar filter ikut kebawa).
  final String initialQuery;

  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState
    extends ConsumerState<AppearanceSettingsPage>
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

  bool _match(String title, String subtitle, [List<String> keys = const []]) {
    if (_q.isEmpty) return true;
    final hay = '$title $subtitle ${keys.join(' ')}'.toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final useDynamic = ref.watch(useDynamicColorProvider);
    final trueBlack = ref.watch(trueBlackProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final compactAmounts = ref.watch(compactAmountsProvider);
    final showTop = ref.watch(showTopCategoriesProvider);
    final showTotals = ref.watch(showMonthTotalsProvider);
    final showDaily = ref.watch(showDailyTotalsProvider);
    final displayName = ref.watch(displayNameProvider);
    final showRecent = ref.watch(showRecentProvider);
    final recentCount = ref.watch(recentCountProvider);
    final compactList = ref.watch(compactListProvider);
    final relativeDates = ref.watch(relativeDatesProvider);
    final showIcons = ref.watch(showCategoryIconsProvider);

    String themeLabel(ThemeMode m) => switch (m) {
          ThemeMode.light => 'Terang',
          ThemeMode.dark => 'Gelap',
          ThemeMode.system => 'Ikuti HP',
        };

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
              child: BackHeader(title: 'Tampilan'),
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
                      hintText: 'Cari di Tampilan…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _q.isNotEmpty
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
                  SettingsGroup(
                    title: 'Warna & tema',
                    children: [
                      if (_match('tema', 'terang gelap ikuti hp',
                          const ['theme', 'dark', 'light']))
                        SettingRow(
                          icon: Icons.brightness_auto_outlined,
                          title: 'Tema',
                          subtitle: themeMode.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: themeLabel,
                          ),
                          trailing: SettingValue(
                            value: themeMode.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: themeLabel,
                            ),
                          ),
                          onTap: pickTheme,
                        ),
                      if (_match('warna aksen', 'hijau biru ungu',
                          const ['accent', 'color']))
                        SettingRow(
                          icon: Icons.palette_outlined,
                          title: 'Warna aksen',
                          subtitle: accent.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: (a) =>
                                AppTheme.accentOptions[a]?.label ?? a,
                          ),
                          trailing: accent.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (a) => CircleAvatar(
                              backgroundColor: AppTheme.seedFor(a),
                              radius: 12,
                            ),
                          ),
                          onTap: () =>
                              pickAccent(AppTheme.accentOptions),
                        ),
                      if (_match('wallpaper', 'material you',
                          const ['dynamic', 'wallpaper']))
                        SettingRow(
                          icon: Icons.wallpaper_outlined,
                          title: 'Ikuti warna wallpaper HP',
                          subtitle:
                              'Material You — Android 12 ke atas, menimpa warna aksen',
                          trailing: Switch(
                            value: useDynamic.value ?? false,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setUseDynamicColor(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setUseDynamicColor(
                                  !(useDynamic.value ?? false)),
                        ),
                      if (_match('hitam pekat', 'oled', const ['black']))
                        SettingRow(
                          icon: Icons.dark_mode_outlined,
                          title: 'Hitam pekat',
                          subtitle:
                              'Background hitam total di mode gelap (hemat OLED)',
                          trailing: Switch(
                            value: trueBlack.value ?? false,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setTrueBlack(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setTrueBlack(
                                  !(trueBlack.value ?? false)),
                        ),
                      if (_match('font', 'ukuran huruf', const ['font']))
                        SettingRow(
                          icon: Icons.format_size,
                          title: 'Ukuran font',
                          subtitle: fontScale.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: fontScaleLabel,
                          ),
                          trailing: SettingValue(
                            value: fontScale.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: fontScaleLabel,
                            ),
                          ),
                          onTap: pickFontScale,
                        ),
                      if (_match('nominal ringkas', 'rp jt rb',
                          const ['compact']))
                        SettingRow(
                          icon: Icons.short_text,
                          title: 'Nominal ringkas',
                          subtitle: compactAmounts.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: (c) => c
                                ? 'Contoh: Rp1,5 jt'
                                : 'Contoh: Rp1.500.000',
                          ),
                          trailing: Switch(
                            value: compactAmounts.value ?? false,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setCompactAmounts(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setCompactAmounts(
                                  !(compactAmounts.value ?? false)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SettingsGroup(
                    title: 'Isi Beranda',
                    children: [
                      if (_match('nama sapaan', 'hai sapa beranda',
                          const ['nama', 'name']))
                        SettingRow(
                          icon: Icons.waving_hand_outlined,
                          title: 'Nama sapaan',
                          subtitle:
                              'Sapaan di Beranda, mis. “Selamat pagi, ReWin”',
                          trailing: SettingValue(
                            value: displayName.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: (n) => n.isEmpty ? 'Ikut akun' : n,
                            ),
                          ),
                          onTap: editDisplayName,
                        ),
                      if (_match('ringkasan harian', 'hari ini',
                          const ['daily', 'hari']))
                        SettingRow(
                          icon: Icons.today_outlined,
                          title: 'Ringkasan hari ini',
                          subtitle:
                              'Masuk / keluar / selisih tanggal hari ini',
                          trailing: Switch(
                            value: showDaily.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setShowDailyTotals(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setShowDailyTotals(
                                  !(showDaily.value ?? true)),
                        ),
                      if (_match('ringkasan', 'masuk keluar',
                          const ['home']))
                        SettingRow(
                          icon: Icons.bar_chart_outlined,
                          title: 'Ringkasan masuk / keluar',
                          subtitle:
                              'Dua angka di bawah saldo bulan berjalan',
                          trailing: Switch(
                            value: showTotals.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setShowMonthTotals(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setShowMonthTotals(
                                  !(showTotals.value ?? true)),
                        ),
                      if (_match('top kategori', 'bar pengeluaran',
                          const ['category']))
                        SettingRow(
                          icon: Icons.category_outlined,
                          title: 'Top kategori bulan ini',
                          subtitle:
                              'Bar pengeluaran per kategori di Beranda',
                          trailing: Switch(
                            value: showTop.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setShowTopCategories(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setShowTopCategories(
                                  !(showTop.value ?? true)),
                        ),
                      if (_match('terakhir', 'riwayat jumlah',
                          const ['recent']))
                        SettingRow(
                          icon: Icons.history,
                          title: 'Terakhir dicatat',
                          subtitle: recentCount.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: (n) =>
                                'Tampilkan $n transaksi terakhir',
                          ),
                          trailing: Switch(
                            value: showRecent.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setShowRecent(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setShowRecent(
                                  !(showRecent.value ?? true)),
                        ),
                      if ((showRecent.value ?? true) &&
                          _match('terakhir', 'jumlah',
                              const ['recent']))
                        SettingRow(
                          icon: Icons.format_list_numbered,
                          title: 'Jumlah ditampilkan',
                          subtitle: recentCount.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: (n) => '$n transaksi',
                          ),
                          trailing: SettingValue(
                            value: recentCount.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: (n) => '$n',
                            ),
                          ),
                          onTap: pickRecentCount,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SettingsGroup(
                    title: 'List & tanggal',
                    children: [
                      if (_match('list rapat', 'padat', const ['dense']))
                        SettingRow(
                          icon: Icons.density_small_outlined,
                          title: 'List rapat',
                          subtitle:
                              'Baris transaksi lebih padat, muat lebih banyak',
                          trailing: Switch(
                            value: compactList.value ?? false,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setCompactList(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setCompactList(
                                  !(compactList.value ?? false)),
                        ),
                      if (_match('tanggal relatif', 'hari ini kemarin',
                          const ['date']))
                        SettingRow(
                          icon: Icons.today_outlined,
                          title: 'Tanggal relatif',
                          subtitle:
                              '"Hari ini / Kemarin" gantikan tanggal penuh di list',
                          trailing: Switch(
                            value: relativeDates.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setRelativeDates(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setRelativeDates(
                                  !(relativeDates.value ?? true)),
                        ),
                      if (_match('ikon kategori', 'emoji', const ['icon']))
                        SettingRow(
                          icon: Icons.emoji_emotions_outlined,
                          title: 'Ikon kategori',
                          subtitle:
                              'Emoji di tiap baris transaksi & laporan',
                          trailing: Switch(
                            value: showIcons.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setShowCategoryIcons(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setShowCategoryIcons(
                                  !(showIcons.value ?? true)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
