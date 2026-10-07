import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Halaman Kelola Kategori — dibuka dari Pengaturan → Kelola kategori.
/// Dipisah dari Pengaturan agar daftar kategori yang panjang tidak
/// membuat halaman Pengaturan ikut panjang.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola kategori')),
      body: cats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada kategori.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showAddCategory(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah kategori'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
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
                          tooltip: 'Hapus ${c.name}',
                          onPressed: () =>
                              _confirmDeleteCat(context, ref, c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddCategory(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Tambah kategori'),
              ),
            ],
          );
        },
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
                    labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ikon emoji (opsional)'),
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
}
