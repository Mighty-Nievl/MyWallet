import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../../data/lock_service.dart';
import '../../data/providers.dart';
import '../../data/reminder_service.dart';
import '../../data/settings.dart';
import '../app_theme.dart';
import '../format.dart';
import 'categories_screen.dart';

/// Layar Pengaturan — dibuka dari ikon kanan atas Beranda.
///
/// Struktur (hasil restruktur v1.3.0):
/// - Tampilan (tema, aksen, wallpaper, hitam pekat, font, nominal ringkas
///   + sub-bagian Isi Beranda + List & tanggal)
/// - Saldo & Privasi (sembunyikan + cakupan, saldo awal, kunci, pengingat)
/// - Kelola (kategori → halaman sendiri, export, backup, restore, hapus)
/// - Tentang (ketuk untuk salin info + changelog)
/// + kolom cari di atas untuk filter cepat.
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

  bool _match(String title, String subtitle, [List<String> keys = const []]) {
    if (_q.isEmpty) return true;
    final hay = '$title $subtitle ${keys.join(' ')}'.toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final hideBalance = ref.watch(hideBalanceProvider);
    final privacyScope = ref.watch(privacyScopeProvider);
    final accent = ref.watch(accentColorProvider);
    final useDynamic = ref.watch(useDynamicColorProvider);
    final trueBlack = ref.watch(trueBlackProvider);
    final compactAmounts = ref.watch(compactAmountsProvider);
    final showTop = ref.watch(showTopCategoriesProvider);
    final showTotals = ref.watch(showMonthTotalsProvider);
    final showDaily = ref.watch(showDailyTotalsProvider);
    final showRecent = ref.watch(showRecentProvider);
    final recentCount = ref.watch(recentCountProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final compactList = ref.watch(compactListProvider);
    final relativeDates = ref.watch(relativeDatesProvider);
    final showIcons = ref.watch(showCategoryIconsProvider);
    final starting = ref.watch(startingBalanceProvider);
    final appLock = ref.watch(appLockProvider);
    final reminder = ref.watch(reminderProvider);
    final cats = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    // Visibilitas seksi saat mencari: hanya tampilkan yang ada isinya.
    final showTampilan = _match('tema', 'terang gelap ikuti hp', const ['theme', 'dark', 'light']) ||
        _match('warna aksen', 'hijau biru ungu oranye merah toska palette', const ['accent', 'color']) ||
        _match('wallpaper', 'material you android 12', const ['dynamic', 'wallpaper']) ||
        _match('hitam pekat', 'oled gelap', const ['black', 'amoled']) ||
        _match('font', 'ukuran huruf kecil normal besar', const ['font']) ||
        _match('nominal ringkas', 'rp jt rb', const ['compact']) ||
        _match('ringkasan beranda', 'masuk keluar saldo', const ['home']) ||
        _match('ringkasan harian', 'hari ini masuk keluar', const ['daily', 'hari']) ||
        _match('top kategori', 'bar pengeluaran', const ['category']) ||
        _match('terakhir dicatat', 'riwayat jumlah', const ['recent']) ||
        _match('list rapat', 'padat compact', const ['dense']) ||
        _match('tanggal relatif', 'hari ini kemarin', const ['date']) ||
        _match('ikon kategori', 'emoji', const ['icon']);
    final showPrivasi = _match('sembunyikan', 'privacy rp', const ['hide', 'privacy']) ||
        _match('cakupan', 'semua nominal saldo', const ['scope']) ||
        _match('saldo awal', 'uang dipegang mulai', const ['balance', 'awal']) ||
        _match('kunci', 'pin biometrik sidik jari wajah', const ['lock', 'pin', 'biometric']) ||
        _match('pengingat', 'notifikasi ingatkan jam', const ['reminder', 'notifikasi']);
    final showKelola = _match('kategori', 'kelola tambah hapus', const ['category']) ||
        _match('export csv', 'file spreadsheet', const ['export', 'csv']) ||
        _match('backup', 'salinan sqlite', const ['backup']) ||
        _match('restore', 'kembalikan hati-hati', const ['restore']) ||
        _match('hapus semua data', 'reset bahaya permanen', const ['delete', 'wipe', 'hapus']);

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
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _q = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) =>
                setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          if (showTampilan) ...[
            _SectionTitle('Tampilan'),
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
                      onTap: () => _pickTheme(context, ref),
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
                        data: (a) =>
                            AppTheme.accentOptions[a]?.label ?? a,
                      )),
                      trailing: accent.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (a) => CircleAvatar(
                          backgroundColor: AppTheme.seedFor(a),
                          radius: 12,
                        ),
                      ),
                      onTap: () => _pickAccent(context, ref),
                    ),
                  if (_match('wallpaper', 'material you',
                      const ['dynamic', 'wallpaper']))
                    const Divider(height: 1),
                  if (_match('wallpaper', 'material you',
                      const ['dynamic', 'wallpaper']))
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
                      onTap: () => _pickFontScale(context, ref),
                    ),
                  if (_match('nominal ringkas', 'rp jt rb',
                      const ['compact']))
                    const Divider(height: 1),
                  if (_match('nominal ringkas', 'rp jt rb',
                      const ['compact']))
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
            _SubTitle('Isi Beranda'),
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
                      subtitle: const Text(
                          'Bar pengeluaran per kategori di Beranda'),
                      value: showTop.value ?? true,
                      onChanged: (v) => ref
                          .read(settingsServiceProvider)
                          .setShowTopCategories(v),
                    ),
                  if (_match('terakhir', 'riwayat jumlah',
                      const ['recent']))
                    const Divider(height: 1),
                  if (_match('terakhir', 'riwayat jumlah',
                      const ['recent']))
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
                      onTap: () => _pickRecentCount(context, ref),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SubTitle('List & tanggal'),
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
                      subtitle: const Text(
                          'Emoji di tiap baris transaksi & laporan'),
                      value: showIcons.value ?? true,
                      onChanged: (v) => ref
                          .read(settingsServiceProvider)
                          .setShowCategoryIcons(v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (showPrivasi) ...[
            _SectionTitle('Saldo & Privasi'),
            Card(
              child: Column(
                children: [
                  if (_match('sembunyikan', 'privacy', const ['hide']))
                    SwitchListTile(
                      secondary: const Icon(Icons.visibility_off),
                      title: const Text('Sembunyikan saldo'),
                      subtitle: Text(privacyScope.when(
                        loading: () => 'Nominal jadi Rp••••',
                        error: (_, _) => 'Nominal jadi Rp••••',
                        data: (s) => s == 'all'
                            ? 'Semua nominal jadi Rp••••'
                            : 'Nominal jadi Rp•••• di Beranda',
                      )),
                      value: hideBalance.value ?? false,
                      onChanged: (v) => ref
                          .read(settingsServiceProvider)
                          .setHideBalance(v),
                    ),
                  if ((hideBalance.value ?? false) &&
                      _match('cakupan', 'semua nominal', const ['scope']))
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Cakupan sembunyikan'),
                      subtitle: Text(privacyScope.when(
                        loading: () => '…',
                        error: (_, _) => 'Gagal memuat',
                        data: (s) => s == 'all'
                            ? 'Semua nominal (saldo + list + laporan)'
                            : 'Hanya saldo Beranda',
                      )),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickPrivacyScope(context, ref),
                    ),
                  if (_match('saldo awal', 'uang mulai', const ['balance']))
                    const Divider(height: 1),
                  if (_match('saldo awal', 'uang mulai', const ['balance']))
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Saldo awal'),
                      subtitle: Text(starting.when(
                        loading: () => '…',
                        error: (_, _) => 'Gagal memuat',
                        data: (s) => s == 0
                            ? 'Belum diatur (mulai dari Rp0)'
                            : formatRp(s),
                      )),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editStartingBalance(context, ref),
                    ),
                  if (_match('kunci', 'pin biometrik', const ['lock']))
                    const Divider(height: 1),
                  if (_match('kunci', 'pin biometrik', const ['lock']))
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Kunci aplikasi'),
                      subtitle: Text(appLock.when(
                        loading: () => '…',
                        error: (_, _) => 'Gagal memuat',
                        data: (m) => switch (m) {
                          'pin' => 'PIN',
                          'biometric' => 'Biometrik',
                          _ => 'Mati',
                        },
                      )),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickLock(context, ref),
                    ),
                  if (_match('pengingat', 'notifikasi', const ['reminder']))
                    const Divider(height: 1),
                  if (_match('pengingat', 'notifikasi', const ['reminder']))
                    reminder.when(
                      loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator()),
                      error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Gagal memuat: $e')),
                      data: (r) => Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.notifications),
                            title: const Text('Ingatkan mencatat'),
                            subtitle: Text(r.enabled
                                ? 'Setiap hari pukul ${_hhmm(r.hour, r.minute)}'
                                : 'Mati'),
                            value: r.enabled,
                            onChanged: (v) => _toggleReminder(
                                context, ref, v, r.hour, r.minute),
                          ),
                          if (r.enabled)
                            ListTile(
                              leading: const Icon(Icons.schedule),
                              title: const Text('Jam pengingat'),
                              subtitle:
                                  Text(_hhmm(r.hour, r.minute)),
                              trailing: const Icon(Icons.edit),
                              onTap: () =>
                                  _pickReminderTime(context, ref),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (showKelola) ...[
            _SectionTitle('Kelola'),
            Card(
              child: Column(
                children: [
                  if (_match('kategori', 'kelola', const ['category']))
                    cats.when(
                      loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator()),
                      error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Gagal memuat: $e')),
                      data: (list) => ListTile(
                        leading: const Icon(Icons.category),
                        title: const Text('Kelola kategori'),
                        subtitle: Text(
                            '${list.length} kategori · ketuk untuk tambah / hapus'),
                        trailing:
                            const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CategoriesScreen()),
                        ),
                      ),
                    ),
                  if (_match('export', 'csv', const ['export']))
                    const Divider(height: 1),
                  if (_match('export', 'csv', const ['export']))
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Export CSV'),
                      subtitle: const Text(
                          'Semua transaksi sebagai file CSV'),
                      onTap: () => _exportCsv(context, ref),
                    ),
                  if (_match('backup', 'salinan', const ['backup']))
                    const Divider(height: 1),
                  if (_match('backup', 'salinan', const ['backup']))
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('Backup database'),
                      subtitle: const Text(
                          'Simpan salinan mywallet.sqlite ke file'),
                      onTap: () => _backupDb(context, ref),
                    ),
                  if (_match('restore', 'kembalikan', const ['restore']))
                    const Divider(height: 1),
                  if (_match('restore', 'kembalikan', const ['restore']))
                    ListTile(
                      leading: Icon(Icons.restore,
                          color: scheme.tertiary),
                      title: Text('Restore database',
                          style:
                              TextStyle(color: scheme.tertiary)),
                      subtitle: const Text(
                          'Hati-hati: menimpa SEMUA data sekarang (wajib restart aplikasi)'),
                      onTap: () => _restoreDb(context, ref),
                    ),
                  if (_match('hapus', 'reset bahaya', const ['delete']))
                    const Divider(height: 1),
                  if (_match('hapus', 'reset bahaya', const ['delete']))
                    ListTile(
                      leading: Icon(Icons.delete_forever,
                          color: scheme.error),
                      title: Text('Hapus semua data',
                          style: TextStyle(color: scheme.error)),
                      subtitle: const Text(
                          'Reset total — transaksi, kategori, budget hilang'),
                      onTap: () => _wipeAll(context, ref),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionTitle('Tentang'),
          _AboutCard(onChangelog: () => _showChangelog(context)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ---------- Tema ----------

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current =
        ref.read(themeModeProvider).value ?? ThemeMode.system;
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in [
                  (ThemeMode.system, 'Ikuti HP'),
                  (ThemeMode.light, 'Terang'),
                  (ThemeMode.dark, 'Gelap'),
                ])
                  RadioListTile<ThemeMode>(
                    title: Text(e.$2),
                    value: e.$1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setThemeMode(switch (picked) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    }
  }

  // ---------- Tampilan: aksen / privacy / font / jumlah ----------

  Future<void> _pickAccent(BuildContext context, WidgetRef ref) async {
    final current = ref.read(accentColorProvider).value ?? 'green';
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Warna aksen'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in AppTheme.accentOptions.entries)
                  RadioListTile<String>(
                    title: Text(e.value.label),
                    secondary: CircleAvatar(
                      backgroundColor: e.value.color,
                      radius: 12,
                    ),
                    value: e.key,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setAccentColor(picked);
    }
  }

  Future<void> _pickPrivacyScope(BuildContext context, WidgetRef ref) async {
    final current = ref.read(privacyScopeProvider).value ?? 'balance';
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Cakupan sembunyikan'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('Hanya saldo Beranda'),
                  subtitle: Text('List & laporan tetap kelihatan'),
                  value: 'balance',
                ),
                RadioListTile<String>(
                  title: Text('Semua nominal'),
                  subtitle: Text('Saldo + list + laporan jadi Rp••••'),
                  value: 'all',
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setPrivacyScope(picked);
    }
  }

  Future<void> _pickFontScale(BuildContext context, WidgetRef ref) async {
    final current = ref.read(fontScaleProvider).value ?? 'normal';
    const options = ['small', 'normal', 'large', 'xlarge'];
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Ukuran font'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in options)
                  RadioListTile<String>(
                    title: Text(fontScaleLabel(o),
                        style: TextStyle(
                            fontSize: 16 * fontScaleValue(o))),
                    value: o,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setFontScale(picked);
    }
  }

  Future<void> _pickRecentCount(BuildContext context, WidgetRef ref) async {
    final current = ref.read(recentCountProvider).value ?? 5;
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Jumlah ditampilkan'),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  title: Text('3 transaksi'),
                  value: 3,
                ),
                RadioListTile<int>(
                  title: Text('5 transaksi'),
                  value: 5,
                ),
                RadioListTile<int>(
                  title: Text('10 transaksi'),
                  value: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setRecentCount(picked);
    }
  }

  // ---------- Saldo awal ----------

  Future<void> _editStartingBalance(
      BuildContext context, WidgetRef ref) async {
    final current = ref.read(startingBalanceProvider).value ?? 0;
    final ctrl =
        TextEditingController(text: current == 0 ? '' : current.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Saldo awal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Uang yang sudah kamu pegang sebelum mulai mencatat. '
                'Ditambahkan ke saldo.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(settingsServiceProvider)
          .setStartingBalance(parseRp(ctrl.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo awal disimpan.')),
        );
      }
    }
  }

  // ---------- Kunci aplikasi ----------

  Future<void> _pickLock(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appLockProvider).value ?? 'none';
    final bioAvailable = await LockService.canUseBiometric();
    if (!context.mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Kunci aplikasi'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(c, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<String>(
                  title: Text('Mati'),
                  value: 'none',
                ),
                const RadioListTile<String>(
                  title: Text('PIN (6 digit)'),
                  value: 'pin',
                ),
                RadioListTile<String>(
                  title: const Text('Biometrik (sidik jari / wajah)'),
                  subtitle: bioAvailable
                      ? null
                      : const Text('Tidak tersedia di HP ini'),
                  value: 'biometric',
                  enabled: bioAvailable,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked == 'none') {
      await ref.read(settingsServiceProvider).setAppLock('none');
      await LockService.clearPin();
      return;
    }
    // PIN wajib ada: sebagai kunci utama (mode pin) maupun cadangan (mode biometrik).
    final needPin = picked == 'pin' || !await LockService.hasPin();
    if (needPin) {
      if (!context.mounted) return;
      final pinOk = await _setupPin(context);
      if (!pinOk) return;
    }
    await ref.read(settingsServiceProvider).setAppLock(picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(picked == 'pin'
                ? 'Kunci PIN aktif.'
                : 'Kunci biometrik aktif.')),
      );
    }
  }

  /// Minta PIN baru 2x (buat + konfirmasi). Return true jika berhasil disimpan.
  Future<bool> _setupPin(BuildContext context) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Buat PIN (6 digit)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'PIN baru', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: second,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                  labelText: 'Ulangi PIN', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return false;
    if (first.text.trim().length < 4) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN minimal 4 digit.')),
        );
      }
      return false;
    }
    if (first.text.trim() != second.text.trim()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN tidak sama, ulangi lagi.')),
        );
      }
      return false;
    }
    await LockService.setPin(first.text.trim());
    return true;
  }

  // ---------- Pengingat ----------

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref,
      bool enable, int hour, int minute) async {
    if (!enable) {
      await ReminderService.cancel();
      await ref.read(settingsServiceProvider).setReminder(false, hour, minute);
      return;
    }
    final granted = await ReminderService.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Izin notifikasi ditolak — pengingat tidak bisa dinyalakan.')),
      );
      return;
    }
    await ReminderService.scheduleDaily(hour, minute);
    await ref.read(settingsServiceProvider).setReminder(true, hour, minute);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Pengingat aktif setiap ${_hhmm(hour, minute)}.')),
      );
    }
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref) async {
    final r = ref.read(reminderProvider).value;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: r?.hour ?? 20, minute: r?.minute ?? 0),
    );
    if (picked == null || !context.mounted) return;
    await ReminderService.scheduleDaily(picked.hour, picked.minute);
    await ref
        .read(settingsServiceProvider)
        .setReminder(true, picked.hour, picked.minute);
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  // ---------- Data: CSV / backup / restore / hapus ----------

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final rows = await db.watchHistory(limit: 100000).first;
    final csvRows = <List<dynamic>>[
      ['tanggal', 'tipe', 'kategori', 'nominal', 'catatan'],
      for (final t in rows)
        [
          t.date.toIso8601String(),
          t.isExpense ? 'keluar' : 'masuk',
          t.catName ?? '',
          t.amount,
          t.note,
        ],
    ];
    final csv = Csv().encode(csvRows);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(
        dir.path, 'mywallet-${DateTime.now().millisecondsSinceEpoch}.csv'));
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Export MyWallet CSV'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV dibuat: ${rows.length} baris.')),
      );
    }
  }

  Future<void> _backupDb(BuildContext context, WidgetRef ref) async {
    try {
      final uri = await BackupService.backupToFile(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(uri == null
                ? 'Backup dibatalkan.'
                : 'Backup berhasil disimpan.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup gagal: $e')),
        );
      }
    }
  }

  Future<void> _restoreDb(BuildContext context, WidgetRef ref) async {
    final src = await BackupService.pickRestoreFile();
    if (src == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore database?'),
        content: const Text(
            'SEMUA data sekarang akan diganti isi file backup. '
            'Setelah restore, tutup total aplikasi lalu buka lagi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.closeDatabase(ref);
      // ignore: use_build_context_synchronously
      await BackupService.restoreFrom(ref, src);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Restore berhasil'),
            content: const Text(
                'Tutup total aplikasi (swipe dari recent apps) lalu buka lagi '
                'untuk memakai data hasil restore.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Mengerti')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore gagal: $e')),
        );
      }
    }
  }

  Future<void> _wipeAll(BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus SEMUA data?'),
        content: const Text(
            'Transaksi, kategori custom, dan budget akan hilang permanen. '
            'Backup dulu kalau masih butuh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Lanjut')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    // Konfirmasi kedua: ketik HAPUS.
    final ctrl = TextEditingController();
    final second = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konfirmasi terakhir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ketik HAPUS (huruf besar) untuk lanjut.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'Ketik HAPUS', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(c, ctrl.text.trim() == 'HAPUS'),
              child: const Text('Hapus permanen')),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    try {
      await BackupService.closeDatabase(ref);
      // ignore: use_build_context_synchronously
      await BackupService.wipeAll(ref);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Data dihapus'),
            content: const Text(
                'Tutup total aplikasi lalu buka lagi untuk mulai dari awal.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Mengerti')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  // ---------- Tentang ----------

  Future<void> _showChangelog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Changelog'),
        content: const SingleChildScrollView(
          child: Text(
            'v1.3.0 — Restruktur Pengaturan (cari, 4 grup, kelola kategori sendiri, tentang tap-to-copy) + ringkasan harian di Beranda.\n\n'
            'v1.2.1 — Warna semantik ikut colorScheme + palet pie tanpa hijau.\n\n'
            'v1.2.0 — Tampilan full (aksen, Material You, true black, privacy all, nominal ringkas, kustom Beranda, overkill).\n\n'
            'v1.1.0 — P0 Pengaturan + bottom bar baru.\n\n'
            'v1.0.1 — Fix saldo reaktif.\n\n'
            'v1.0.0 — MVP awal.',
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tutup')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.onChangelog});
  final VoidCallback onChangelog;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final v = snap.data;
            final info =
                'MyWallet v${v?.version ?? '…'} (${v?.buildNumber ?? '…'})';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$info\n'
                        'Pencatat keuangan pribadi — offline-first.\n'
                        'Seluruh data tersimpan lokal di HP kamu.',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Salin info versi',
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: info));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Info versi disalin — tempel saat lapor bug.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onChangelog,
                  icon: const Icon(Icons.history),
                  label: const Text('Lihat changelog'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
