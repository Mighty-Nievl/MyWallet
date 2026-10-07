import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../format.dart';

/// Form tambah / edit transaksi.
class TxFormScreen extends ConsumerStatefulWidget {
  const TxFormScreen({super.key, this.existing});

  final TxWithCategory? existing;

  @override
  ConsumerState<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends ConsumerState<TxFormScreen> {
  late bool _isExpense;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isExpense = e?.isExpense ?? true;
    _amountCtrl =
        TextEditingController(text: e != null ? e.amount.toString() : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _editing => widget.existing != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
            picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _save() async {
    final amount = parseRp(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nominal dulu (lebih dari 0).')),
      );
      return;
    }
    if (_editing) {
      await updateTransaction(
        ref,
        id: widget.existing!.id,
        amount: amount,
        isExpense: _isExpense,
        categoryId: _categoryId,
        date: _date,
        note: _noteCtrl.text,
      );
    } else {
      await addTransaction(
        ref,
        amount: amount,
        isExpense: _isExpense,
        categoryId: _categoryId,
        date: _date,
        note: _noteCtrl.text,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await deleteTransaction(ref, widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(
        _isExpense ? expenseCategoriesProvider : incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Transaksi' : 'Catat Transaksi'),
        actions: [
          if (_editing)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  label: Text('Keluar'),
                  icon: Icon(Icons.arrow_upward)),
              ButtonSegment(
                  value: false,
                  label: Text('Masuk'),
                  icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_isExpense},
            onSelectionChanged: (s) => setState(() {
              _isExpense = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal (Rp)',
              hintText: 'cth. 25000',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          catsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat kategori: $e'),
            data: (cats) => DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Tanpa kategori')),
                for (final c in cats)
                  DropdownMenuItem(
                      value: c.id, child: Text('${c.icon} ${c.name}')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'cth. makan siang di warteg',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(formatDateTime(_date)),
            subtitle: const Text('Tanggal transaksi'),
            trailing: const Icon(Icons.edit),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_editing ? 'Simpan Perubahan' : 'Simpan Transaksi'),
          ),
          TextButton(
            onPressed: () => _showAddCategory(context),
            child: const Text('+ Tambah kategori baru'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategory(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kategori baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nama', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(
                labelText: 'Ikon emoji (opsional)',
                hintText: 'cth. 🍜',
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
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final id = await addCategory(
        ref,
        name: nameCtrl.text,
        icon: iconCtrl.text,
        isExpense: _isExpense,
      );
      setState(() => _categoryId = id);
    }
  }
}
