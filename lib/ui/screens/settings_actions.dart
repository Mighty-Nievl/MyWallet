import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../../data/lock_service.dart';
import '../../data/providers.dart';
import '../../data/reminder_service.dart';
import '../../data/settings.dart';
import '../amount_input.dart';
import '../format.dart';

/// Aksi Pengaturan yang dipakai ulang oleh semua sub-halaman
/// (Tampilan, Saldo & Privasi, Kelola, Tentang).
///
/// Ditaruh di mixin agar dialog + logika (PIN, backup, restore, export)
/// cukup ditulis sekali. Cara pakai:
/// `class _XState extends ConsumerState<X> with SettingsActions {}`
/// lalu panggil `pickTheme()`, `backupDb()`, dst. tanpa argumen.
mixin SettingsActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  // ---------- Tema ----------

  Future<void> pickTheme() async {
    final current = ref.read(themeModeProvider).value ?? ThemeMode.system;
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

  Future<void> pickAccent(
      Map<String, ({String label, Color color})> options) async {
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
                for (final e in options.entries)
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

  Future<void> pickPrivacyScope() async {
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

  Future<void> pickFontScale() async {
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

  Future<void> pickRecentCount() async {
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

  Future<void> editStartingBalance() async {
    final current = ref.read(startingBalanceProvider).value ?? 0;
    final ctrl = TextEditingController(
        text: current == 0 ? '' : formatAmountField(current));
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
              inputFormatters: [ThousandSeparatorInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                hintText: 'cth. 5.000.000',
                prefixText: 'Rp ',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo awal disimpan.')),
        );
      }
    }
  }

  // ---------- Kunci aplikasi ----------

  Future<void> pickLock() async {
    final current = ref.read(appLockProvider).value ?? 'none';
    final bioAvailable = await LockService.canUseBiometric();
    if (!mounted) return;
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
    if (picked == null || !mounted) return;
    if (picked == 'none') {
      await ref.read(settingsServiceProvider).setAppLock('none');
      await LockService.clearPin();
      return;
    }
    // PIN wajib ada: sebagai kunci utama (mode pin) maupun cadangan (mode biometrik).
    final needPin = picked == 'pin' || !await LockService.hasPin();
    if (needPin) {
      if (!mounted) return;
      final pinOk = await setupPin();
      if (!pinOk) return;
    }
    await ref.read(settingsServiceProvider).setAppLock(picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(picked == 'pin'
                ? 'Kunci PIN aktif.'
                : 'Kunci biometrik aktif.')),
      );
    }
  }

  /// Minta PIN baru 2x (buat + konfirmasi). Return true jika berhasil disimpan.
  Future<bool> setupPin() async {
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
                  labelText: 'PIN baru'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: second,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                  labelText: 'Ulangi PIN'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN minimal 4 digit.')),
        );
      }
      return false;
    }
    if (first.text.trim() != second.text.trim()) {
      if (mounted) {
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

  Future<void> toggleReminder(bool enable, int hour, int minute) async {
    if (!enable) {
      await ReminderService.cancel();
      await ref.read(settingsServiceProvider).setReminder(false, hour, minute);
      return;
    }
    final granted = await ReminderService.requestPermission();
    if (!mounted) return;
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengingat aktif setiap ${hhmm(hour, minute)}.')),
      );
    }
  }

  Future<void> pickReminderTime() async {
    final r = ref.read(reminderProvider).value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r?.hour ?? 20, minute: r?.minute ?? 0),
    );
    if (picked == null || !mounted) return;
    await ReminderService.scheduleDaily(picked.hour, picked.minute);
    await ref
        .read(settingsServiceProvider)
        .setReminder(true, picked.hour, picked.minute);
  }

  // ---------- Data: CSV / backup / restore / hapus ----------

  Future<void> exportCsv() async {
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV dibuat: ${rows.length} baris.')),
      );
    }
  }

  Future<void> backupDb() async {
    try {
      final uri = await BackupService.backupToFile(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(uri == null
                ? 'Backup dibatalkan.'
                : 'Backup berhasil disimpan.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup gagal: $e')),
        );
      }
    }
  }

  Future<void> restoreDb() async {
    final src = await BackupService.pickRestoreFile();
    if (src == null || !mounted) return;
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
      await BackupService.restoreFrom(ref, src);
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore gagal: $e')),
        );
      }
    }
  }

  Future<void> wipeAll() async {
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
    if (first != true || !mounted) return;
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
                  labelText: 'Ketik HAPUS'),
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
    if (second != true || !mounted) return;
    try {
      await BackupService.closeDatabase(ref);
      await BackupService.wipeAll(ref);
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  // ---------- Tentang ----------

  Future<void> showChangelog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => const AlertDialog(
        title: Text('Changelog'),
        content: SingleChildScrollView(
          child: Text(
            'v1.6.0 — Redesign STEP 2: Riwayat + Form Transaksi baru (visual saja, logika utuh).\n\n'
            'v1.3.0 — Restruktur Pengaturan (cari, 4 grup, kelola kategori sendiri, tentang tap-to-copy) + ringkasan harian di Beranda.\n\n'
            'v1.2.1 — Warna semantik ikut colorScheme + palet pie tanpa hijau.\n\n'
            'v1.2.0 — Tampilan full (aksen, Material You, true black, privacy all, nominal ringkas, kustom Beranda, overkill).\n\n'
            'v1.1.0 — P0 Pengaturan + bottom bar baru.\n\n'
            'v1.0.1 — Fix saldo reaktif.\n\n'
            'v1.0.0 — MVP awal.',
          ),
        ),
        actions: [
          _ChangelogClose(),
        ],
      ),
    );
  }
}

class _ChangelogClose extends StatelessWidget {
  const _ChangelogClose();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'));
  }
}
