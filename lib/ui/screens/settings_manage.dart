import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/setting_row.dart';
import '../components/settings_scaffold.dart';
import '../design/app_spacing.dart';
import '../format.dart';
import 'categories_screen.dart';
import 'settings_actions.dart';
import 'settings_catalog.dart';

/// Sub-halaman Kelola: kategori (halaman sendiri), export CSV/PDF, backup,
/// restore (kuning), hapus semua data (merah).
///
/// v1.43.0: kerangka [SettingsScaffold], switch [SettingSwitch], filter dari
/// [SettingsCatalog] — "Export PDF laporan", "Backup otomatis", "Backup
/// terakhir" dan "Pulihkan backup otomatis" kini ikut ketemu dari pencarian.
class ManageSettingsPage extends ConsumerStatefulWidget {
  const ManageSettingsPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ManageSettingsPage> createState() => _ManageSettingsPageState();
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

  bool _show(String id) => SettingsCatalog.byId(id).matches(_q);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catCount = ref.watch(categoriesProvider).value?.length;
    final autoBackup = ref.watch(autoBackupEnabledProvider).value ?? true;
    final lastBackup = ref.watch(lastBackupAtProvider).value;
    final service = ref.read(settingsServiceProvider);

    return SettingsScaffold(
      title: 'Kelola',
      search: SettingsSearchField(
        controller: _searchCtrl,
        hint: 'Cari di Kelola…',
        query: _q,
        onChanged: (v) => setState(() => _q = v),
      ),
      children: [
        SettingsGroup(
          title: 'Data',
          children: [
            if (_show('kelola-kategori'))
              SettingRow(
                icon: Icons.category_outlined,
                title: 'Kelola kategori',
                subtitle: catCount == null
                    ? '…'
                    : '$catCount kategori · ketuk untuk tambah / hapus',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                ),
              ),
            if (_show('export-csv'))
              SettingRow(
                icon: Icons.download_outlined,
                title: 'Export CSV',
                subtitle: 'Semua transaksi sebagai file CSV',
                onTap: exportCsv,
              ),
            if (_show('export-pdf'))
              SettingRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export PDF laporan',
                subtitle: 'Ringkasan + rincian bulan aktif (100% offline)',
                onTap: exportMonthPdf,
              ),
            if (_show('backup-db'))
              SettingRow(
                icon: Icons.backup_outlined,
                title: 'Backup database',
                subtitle: 'Simpan salinan mywallet.sqlite ke file',
                onTap: backupDb,
              ),
            if (_show('backup-otomatis'))
              SettingSwitch(
                icon: Icons.settings_backup_restore,
                title: 'Backup otomatis',
                subtitle: autoBackup
                    ? 'Tiap hari, 5 salinan terakhir di HP'
                    : 'Mati — backup hanya saat tombol ditekan',
                value: autoBackup,
                onChanged: service.setAutoBackup,
              ),
            if (_show('backup-terakhir'))
              SettingRow(
                icon: Icons.schedule,
                title: 'Backup terakhir',
                subtitle: lastBackup == null
                    ? 'Belum pernah — data hanya ada di HP ini'
                    : backupAgeLabel(lastBackup),
                trailing: TextButton(
                  onPressed: backupNow,
                  child: const Text('Sekarang'),
                ),
              ),
            if (_show('pulihkan-auto'))
              SettingRow(
                icon: Icons.restore,
                title: 'Pulihkan backup otomatis',
                subtitle: 'Pilih salinan harian yang tersimpan di HP',
                onTap: restoreAuto,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SettingsGroup(
          title: 'Zona berbahaya',
          titleColor: scheme.error,
          children: [
            if (_show('restore-db'))
              SettingRow(
                icon: Icons.restore,
                title: 'Restore database',
                subtitle:
                    'Hati-hati: menimpa SEMUA data sekarang (wajib restart aplikasi)',
                onTap: restoreDb,
              ),
            if (_show('hapus-data'))
              SettingRow(
                icon: Icons.delete_forever_outlined,
                title: 'Hapus semua data',
                subtitle: 'Reset total — transaksi, kategori, budget hilang',
                destructive: true,
                onTap: wipeAll,
              ),
          ],
        ),
      ],
    );
  }
}
