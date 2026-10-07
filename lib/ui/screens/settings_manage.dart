import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'categories_screen.dart';
import 'settings_actions.dart';

/// Sub-halaman Kelola: kategori (halaman sendiri), export CSV,
/// backup, restore (kuning), hapus semua data (merah).
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
    final cats = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
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
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CategoriesScreen()),
                      ),
                    ),
                  ),
                if (_match('export', 'csv', const ['export']))
                  const Divider(height: 1),
                if (_match('export', 'csv', const ['export']))
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Export CSV'),
                    subtitle:
                        const Text('Semua transaksi sebagai file CSV'),
                    onTap: exportCsv,
                  ),
                if (_match('backup', 'salinan', const ['backup']))
                  const Divider(height: 1),
                if (_match('backup', 'salinan', const ['backup']))
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text('Backup database'),
                    subtitle: const Text(
                        'Simpan salinan mywallet.sqlite ke file'),
                    onTap: backupDb,
                  ),
                if (_match('restore', 'kembalikan', const ['restore']))
                  const Divider(height: 1),
                if (_match('restore', 'kembalikan', const ['restore']))
                  ListTile(
                    leading:
                        Icon(Icons.restore, color: scheme.tertiary),
                    title: Text('Restore database',
                        style: TextStyle(color: scheme.tertiary)),
                    subtitle: const Text(
                        'Hati-hati: menimpa SEMUA data sekarang (wajib restart aplikasi)'),
                    onTap: restoreDb,
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
                    onTap: wipeAll,
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
