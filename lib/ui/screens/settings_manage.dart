import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../format.dart';
import 'categories_screen.dart';
import 'settings_actions.dart';

/// Sub-halaman Kelola: kategori (halaman sendiri), export CSV,
/// backup, restore (kuning), hapus semua data (merah).
///
/// STEP 4 — hanya presentasi yang diubah. Semua aksi (via
/// [SettingsActions]), navigasi, filter cari, hirarki destruktif TETAP.
class ManageSettingsPage extends ConsumerStatefulWidget {
  const ManageSettingsPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ManageSettingsPage> createState() =>
      _ManageSettingsPageState();
}

class _ManageSettingsPageState extends ConsumerState<ManageSettingsPage>
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
    final scheme = Theme.of(context).colorScheme;
    final cats = ref.watch(categoriesProvider);
    final autoBackup = ref.watch(autoBackupEnabledProvider);
    final lastBackup = ref.watch(lastBackupAtProvider);

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
              child: BackHeader(title: 'Kelola'),
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
                      hintText: 'Cari di Kelola…',
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
                    title: 'Data',
                    children: [
                      if (_match('kategori', 'kelola', const ['category']))
                        cats.when(
                          loading: () => const Padding(
                              padding: AppSpacing.cardPadding,
                              child: AppSkeleton(lines: 2)),
                          error: (_, _) => const Padding(
                              padding: AppSpacing.cardPadding,
                              child:
                                  Text('Gagal memuat kategori.')),
                          data: (list) => SettingRow(
                            icon: Icons.category_outlined,
                            title: 'Kelola kategori',
                            subtitle:
                                '${list.length} kategori · ketuk untuk tambah / hapus',
                            onTap: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const CategoriesScreen()),
                            ),
                          ),
                        ),
                      if (_match('export', 'csv', const ['export']))
                        SettingRow(
                          icon: Icons.download_outlined,
                          title: 'Export CSV',
                          subtitle:
                              'Semua transaksi sebagai file CSV',
                          onTap: exportCsv,
                        ),
                      if (_match('laporan', 'pdf', const ['pdf', 'laporan']))
                        SettingRow(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'Export PDF laporan',
                          subtitle:
                              'Ringkasan + rincian bulan aktif (100% offline)',
                          onTap: exportMonthPdf,
                        ),
                      if (_match('backup', 'salinan', const ['backup']))
                        SettingRow(
                          icon: Icons.backup_outlined,
                          title: 'Backup database',
                          subtitle:
                              'Simpan salinan mywallet.sqlite ke file',
                          onTap: backupDb,
                        ),
                      // v1.39.0: backup harian otomatis — jawaban untuk
                      // "user tidak pernah menekan tombol backup".
                      if (_match(
                          'backup otomatis', 'harian salinan', const ['auto']))
                        SettingRow(
                          icon: Icons.settings_backup_restore,
                          title: 'Backup otomatis',
                          subtitle: autoBackup.when(
                            loading: () =>
                                'Tiap hari, 5 salinan terakhir di HP',
                            error: (_, _) =>
                                'Tiap hari, 5 salinan terakhir di HP',
                            data: (on) => on
                                ? 'Tiap hari, 5 salinan terakhir di HP'
                                : 'Mati — backup hanya saat tombol ditekan',
                          ),
                          trailing: Switch(
                            value: autoBackup.value ?? true,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setAutoBackup(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setAutoBackup(!(autoBackup.value ?? true)),
                        ),
                      if (_match('backup terakhir', 'terakhir kapan',
                          const ['backup', 'last']))
                        SettingRow(
                          icon: Icons.schedule,
                          title: 'Backup terakhir',
                          subtitle: lastBackup.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal membaca',
                            data: (d) => d == null
                                ? 'Belum pernah — data hanya ada di HP ini'
                                : backupAgeLabel(d),
                          ),
                          trailing: TextButton(
                            onPressed: backupNow,
                            child: const Text('Sekarang'),
                          ),
                        ),
                      if (_match('pulihkan backup', 'restore salinan',
                          const ['restore', 'auto']))
                        SettingRow(
                          icon: Icons.restore,
                          title: 'Pulihkan backup otomatis',
                          subtitle:
                              'Pilih salinan harian yang tersimpan di HP',
                          onTap: restoreAuto,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SettingsGroup(
                    title: 'Zona berbahaya',
                    titleColor: scheme.error,
                    children: [
                      if (_match('restore', 'kembalikan', const ['restore']))
                        SettingRow(
                          icon: Icons.restore,
                          title: 'Restore database',
                          subtitle:
                              'Hati-hati: menimpa SEMUA data sekarang (wajib restart aplikasi)',
                          onTap: restoreDb,
                        ),
                      if (_match('hapus', 'reset bahaya', const ['delete']))
                        SettingRow(
                          icon: Icons.delete_forever_outlined,
                          title: 'Hapus semua data',
                          subtitle:
                              'Reset total — transaksi, kategori, budget hilang',
                          destructive: true,
                          onTap: wipeAll,
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
