import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
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
                              padding: EdgeInsets.all(16),
                              child: AppSkeleton(lines: 2)),
                          error: (_, _) => const Padding(
                              padding: EdgeInsets.all(16),
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
