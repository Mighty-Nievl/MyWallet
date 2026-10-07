import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../app_theme.dart';
import 'settings_actions.dart';

/// Sub-halaman Tampilan: tema, aksen, wallpaper, hitam pekat, font,
/// nominal ringkas + sub-bagian Isi Beranda + List & tanggal.
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
    final showRecent = ref.watch(showRecentProvider);
    final recentCount = ref.watch(recentCountProvider);
    final compactList = ref.watch(compactListProvider);
    final relativeDates = ref.watch(relativeDatesProvider);
    final showIcons = ref.watch(showCategoryIconsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          const _SubHead('Warna & tema'),
          Card(
            child: Column(
              children: [
                if (_match('tema', 'terang gelap ikuti hp',
                    const ['theme', 'dark', 'light']))
                  ListTile(
                    leading: const Icon(Icons.brightness_auto),
                    title: const Text('Tema'),
                    subtitle: Text(themeMode.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (m) => switch (m) {
                        ThemeMode.light => 'Terang',
                        ThemeMode.dark => 'Gelap',
                        ThemeMode.system => 'Ikuti HP',
                      },
                    )),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: pickTheme,
                  ),
                if (_match('warna aksen', 'hijau biru ungu',
                    const ['accent', 'color']))
                  const Divider(height: 1),
                if (_match('warna aksen', 'hijau biru ungu',
                    const ['accent', 'color']))
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Warna aksen'),
                    subtitle: Text(accent.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (a) => AppTheme.accentOptions[a]?.label ?? a,
                    )),
                    trailing: accent.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (a) => CircleAvatar(
                        backgroundColor: AppTheme.seedFor(a),
                        radius: 12,
                      ),
                    ),
                    onTap: () => pickAccent(AppTheme.accentOptions),
                  ),
                if (_match(
                    'wallpaper', 'material you', const ['dynamic', 'wallpaper']))
                  const Divider(height: 1),
                if (_match(
                    'wallpaper', 'material you', const ['dynamic', 'wallpaper']))
                  SwitchListTile(
                    secondary: const Icon(Icons.wallpaper),
                    title: const Text('Ikuti warna wallpaper HP'),
                    subtitle: const Text(
                        'Material You — Android 12 ke atas, menimpa warna aksen'),
                    value: useDynamic.value ?? false,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setUseDynamicColor(v),
                  ),
                if (_match('hitam pekat', 'oled', const ['black']))
                  const Divider(height: 1),
                if (_match('hitam pekat', 'oled', const ['black']))
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text('Hitam pekat'),
                    subtitle: const Text(
                        'Background hitam total di mode gelap (hemat OLED)'),
                    value: trueBlack.value ?? false,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setTrueBlack(v),
                  ),
                if (_match('font', 'ukuran huruf', const ['font']))
                  const Divider(height: 1),
                if (_match('font', 'ukuran huruf', const ['font']))
                  ListTile(
                    leading: const Icon(Icons.format_size),
                    title: const Text('Ukuran font'),
                    subtitle: Text(fontScale.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (f) => fontScaleLabel(f),
                    )),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: pickFontScale,
                  ),
                if (_match('nominal ringkas', 'rp jt rb', const ['compact']))
                  const Divider(height: 1),
                if (_match('nominal ringkas', 'rp jt rb', const ['compact']))
                  SwitchListTile(
                    secondary: const Icon(Icons.short_text),
                    title: const Text('Nominal ringkas'),
                    subtitle: Text(compactAmounts.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (c) =>
                          c ? 'Contoh: Rp1,5 jt' : 'Contoh: Rp1.500.000',
                    )),
                    value: compactAmounts.value ?? false,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setCompactAmounts(v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SubHead('Isi Beranda'),
          Card(
            child: Column(
              children: [
                if (_match('ringkasan harian', 'hari ini',
                    const ['daily', 'hari']))
                  SwitchListTile(
                    secondary: const Icon(Icons.today),
                    title: const Text('Ringkasan hari ini'),
                    subtitle: const Text(
                        'Masuk / keluar / selisih tanggal hari ini'),
                    value: showDaily.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setShowDailyTotals(v),
                  ),
                if (_match('ringkasan', 'masuk keluar', const ['home']))
                  const Divider(height: 1),
                if (_match('ringkasan', 'masuk keluar', const ['home']))
                  SwitchListTile(
                    secondary: const Icon(Icons.bar_chart),
                    title: const Text('Ringkasan masuk / keluar'),
                    subtitle: const Text(
                        'Dua angka di bawah saldo bulan berjalan'),
                    value: showTotals.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setShowMonthTotals(v),
                  ),
                if (_match('top kategori', 'bar pengeluaran',
                    const ['category']))
                  const Divider(height: 1),
                if (_match('top kategori', 'bar pengeluaran',
                    const ['category']))
                  SwitchListTile(
                    secondary: const Icon(Icons.category),
                    title: const Text('Top kategori bulan ini'),
                    subtitle:
                        const Text('Bar pengeluaran per kategori di Beranda'),
                    value: showTop.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setShowTopCategories(v),
                  ),
                if (_match('terakhir', 'riwayat jumlah', const ['recent']))
                  const Divider(height: 1),
                if (_match('terakhir', 'riwayat jumlah', const ['recent']))
                  SwitchListTile(
                    secondary: const Icon(Icons.history),
                    title: const Text('Terakhir dicatat'),
                    subtitle: Text(recentCount.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (n) => 'Tampilkan $n transaksi terakhir',
                    )),
                    value: showRecent.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setShowRecent(v),
                  ),
                if ((showRecent.value ?? true) &&
                    _match('terakhir', 'jumlah', const ['recent']))
                  ListTile(
                    leading: const Icon(Icons.format_list_numbered),
                    title: const Text('Jumlah ditampilkan'),
                    subtitle: Text(recentCount.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (n) => '$n transaksi',
                    )),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: pickRecentCount,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SubHead('List & tanggal'),
          Card(
            child: Column(
              children: [
                if (_match('list rapat', 'padat', const ['dense']))
                  SwitchListTile(
                    secondary: const Icon(Icons.density_small),
                    title: const Text('List rapat'),
                    subtitle: const Text(
                        'Baris transaksi lebih padat, muat lebih banyak'),
                    value: compactList.value ?? false,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setCompactList(v),
                  ),
                if (_match('tanggal relatif', 'hari ini kemarin',
                    const ['date']))
                  const Divider(height: 1),
                if (_match('tanggal relatif', 'hari ini kemarin',
                    const ['date']))
                  SwitchListTile(
                    secondary: const Icon(Icons.today),
                    title: const Text('Tanggal relatif'),
                    subtitle: const Text(
                        '"Hari ini / Kemarin" gantikan tanggal penuh di list'),
                    value: relativeDates.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setRelativeDates(v),
                  ),
                if (_match('ikon kategori', 'emoji', const ['icon']))
                  const Divider(height: 1),
                if (_match('ikon kategori', 'emoji', const ['icon']))
                  SwitchListTile(
                    secondary: const Icon(Icons.emoji_emotions),
                    title: const Text('Ikon kategori'),
                    subtitle:
                        const Text('Emoji di tiap baris transaksi & laporan'),
                    value: showIcons.value ?? true,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setShowCategoryIcons(v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SubHead extends StatelessWidget {
  const _SubHead(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
