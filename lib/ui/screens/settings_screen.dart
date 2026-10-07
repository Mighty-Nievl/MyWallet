import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../format.dart';

/// Layar pengaturan: kategori, export CSV, info aplikasi.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Kategori', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          cats.when(
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator())),
            error: (e, _) => Text('Gagal memuat: $e'),
            data: (list) => Card(
              child: Column(
                children: [
                  for (final c in list)
                    ListTile(
                      leading: Text(c.icon,
                          style: const TextStyle(fontSize: 20)),
                      title: Text(c.name),
                      subtitle: Text(
                          c.isExpense ? 'Pengeluaran' : 'Pemasukan'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDeleteCat(context, ref, c),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Tambah kategori'),
                    onTap: () => _showAddCategory(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export CSV'),
                  subtitle: const Text(
                      'Unduh semua transaksi sebagai file CSV'),
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Tentang', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'MyWallet v1.0.0\n'
                'Pencatat keuangan pribadi — offline-first.\n'
                'Seluruh data tersimpan lokal di HP kamu.',
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showAddCategory(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    var isExpense = true;
    final ok = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Kategori baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nama', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ikon emoji (opsional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Keluar')),
                  ButtonSegment(value: false, label: Text('Masuk')),
                ],
                selected: {isExpense},
                onSelectionChanged: (s) =>
                    setS(() => isExpense = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Tambah')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await addCategory(ref,
          name: nameCtrl.text, icon: iconCtrl.text, isExpense: isExpense);
    }
  }

  Future<void> _confirmDeleteCat(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${c.name}"?'),
        content: const Text(
            'Transaksi yang memakai kategori ini jadi "Tanpa kategori".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await deleteCategory(ref, c.id);
  }

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
        SnackBar(content: Text('CSV dibuat: ${formatRp(rows.length)} baris.')),
      );
    }
  }
}
