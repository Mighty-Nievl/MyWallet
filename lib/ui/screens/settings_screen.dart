import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/actions.dart';
import '../../data/backup_service.dart';
import '../../data/database.dart';
import '../../data/lock_service.dart';
import '../../data/providers.dart';
import '../../data/reminder_service.dart';
import '../../data/settings.dart';
import '../format.dart';

/// Layar Pengaturan — dibuka dari ikon kanan atas Beranda.
/// Grup: Tampilan · Keuangan · Kategori · Keamanan · Pengingat · Data · Tentang.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final hideBalance = ref.watch(hideBalanceProvider);
    final starting = ref.watch(startingBalanceProvider);
    final appLock = ref.watch(appLockProvider);
    final reminder = ref.watch(reminderProvider);
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Tampilan'),
          Card(
            child: Column(
              children: [
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
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off),
                  title: const Text('Sembunyikan saldo'),
                  subtitle: const Text('Nominal jadi Rp•••• di Beranda'),
                  value: hideBalance.value ?? false,
                  onChanged: (v) => ref
                      .read(settingsServiceProvider)
                      .setHideBalance(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('Keuangan'),
          Card(
            child: ListTile(
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
          ),
          const SizedBox(height: 16),
          _SectionTitle('Kategori'),
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
          _SectionTitle('Keamanan'),
          Card(
            child: ListTile(
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
          ),
          const SizedBox(height: 16),
          _SectionTitle('Pengingat harian'),
          Card(
            child: reminder.when(
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
                    onChanged: (v) =>
                        _toggleReminder(context, ref, v, r.hour, r.minute),
                  ),
                  if (r.enabled)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Jam pengingat'),
                      subtitle: Text(_hhmm(r.hour, r.minute)),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _pickReminderTime(context, ref),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export CSV'),
                  subtitle:
                      const Text('Semua transaksi sebagai file CSV'),
                  onTap: () => _exportCsv(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup database'),
                  subtitle: const Text(
                      'Simpan salinan mywallet.sqlite ke file'),
                  onTap: () => _backupDb(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore database'),
                  subtitle: const Text(
                      'Kembalikan dari file backup (aplikasi harus di-restart)'),
                  onTap: () => _restoreDb(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Hapus semua data',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  subtitle: const Text(
                      'Reset total — transaksi, kategori, budget hilang'),
                  onTap: () => _wipeAll(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('Tentang'),
          const _AboutCard(),
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

  // ---------- Kategori (seperti sebelumnya) ----------

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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final v = snap.data;
            return Text(
              'MyWallet v${v?.version ?? '…'} (${v?.buildNumber ?? '…'})\n'
              'Pencatat keuangan pribadi — offline-first.\n'
              'Seluruh data tersimpan lokal di HP kamu.',
            );
          },
        ),
      ),
    );
  }
}
