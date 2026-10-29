import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_backup.dart';
import '../../data/backup_service.dart';
import '../../data/export_service.dart';
import '../../data/lock_service.dart';
import '../../data/providers.dart';
import '../../data/reminder_service.dart';
import '../../data/report_pdf_service.dart';
import '../../data/settings.dart';
import '../amount_input.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../format.dart';

/// Aksi Pengaturan yang dipakai ulang oleh semua sub-halaman
/// (Tampilan, Saldo & Privasi, Kelola, Tentang).
///
/// STEP 4 — hanya presentasi dialog yang diubah. Logika TETAP:
/// semua setter, PIN, backup, restore, export, reminder, changelog.
/// Cara pakai:
/// `class _XState extends ConsumerState<X> with SettingsActions {}`
/// lalu panggil `pickTheme()`, `backupDb()`, dst. tanpa argumen.
mixin SettingsActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Pemilih satu opsi ala STEP 4: baris konsisten (ikon kotak
  /// subtle + judul + deskripsi + indikator cek). Kembalian null
  /// bila dialog dibatalkan. Nilai & urutan opsi TETAP milik pemanggil.
  Future<V?> _pickSingle<V>({
    required String title,
    required V groupValue,
    required List<_PickOption<V>> options,
  }) async {
    return showDialog<V>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s12, AppSpacing.page, AppSpacing.s8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                _PickRow<V>(
                  option: o,
                  selected: o.value == groupValue,
                  onTap: o.enabled
                      ? () => Navigator.pop(c, o.value)
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Batal')),
        ],
      ),
    );
  }

  // ---------- Tema ----------

  Future<void> pickTheme() async {
    final current = ref.read(themeModeProvider).value ?? ThemeMode.system;
    final picked = await _pickSingle<ThemeMode>(
      title: 'Tema',
      groupValue: current,
      options: const [
        _PickOption(
            value: ThemeMode.system,
            icon: Icons.brightness_auto_outlined,
            title: 'Ikuti HP',
            subtitle: 'Mengikuti tema sistem'),
        _PickOption(
            value: ThemeMode.light,
            icon: Icons.light_mode_outlined,
            title: 'Terang',
            subtitle: 'Selalu terang'),
        _PickOption(
            value: ThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            title: 'Gelap',
            subtitle: 'Selalu gelap'),
      ],
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
      builder: (c) => AlertDialog(
        title: const Text('Warna aksen'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s12,
            alignment: WrapAlignment.start,
            children: [
              for (final e in options.entries)
                _AccentDot(
                  label: e.value.label,
                  color: e.value.color,
                  selected: e.key == current,
                  onTap: () => Navigator.pop(c, e.key),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Batal')),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setAccentColor(picked);
    }
  }

  Future<void> pickPrivacyScope() async {
    final current = ref.read(privacyScopeProvider).value ?? 'balance';
    final picked = await _pickSingle<String>(
      title: 'Cakupan sembunyikan',
      groupValue: current,
      options: const [
        _PickOption(
            value: 'balance',
            icon: Icons.visibility_off_outlined,
            title: 'Hanya saldo Beranda',
            subtitle: 'List & laporan tetap kelihatan'),
        _PickOption(
            value: 'all',
            icon: Icons.privacy_tip_outlined,
            title: 'Semua nominal',
            subtitle: 'Saldo + list + laporan jadi Rp••••'),
      ],
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setPrivacyScope(picked);
    }
  }

  Future<void> pickFontScale() async {
    final current = ref.read(fontScaleProvider).value ?? 'normal';
    const options = ['small', 'normal', 'large', 'xlarge'];
    final picked = await _pickSingle<String>(
      title: 'Ukuran font',
      groupValue: current,
      options: [
        for (final o in options)
          _PickOption(
            value: o,
            icon: Icons.format_size,
            title: fontScaleLabel(o),
            subtitle: null,
            previewSize: 16 * fontScaleValue(o),
          ),
      ],
    );
    if (picked != null) {
      await ref.read(settingsServiceProvider).setFontScale(picked);
    }
  }

  Future<void> pickRecentCount() async {
    final current = ref.read(recentCountProvider).value ?? 5;
    final picked = await _pickSingle<int>(
      title: 'Jumlah ditampilkan',
      groupValue: current,
      options: const [
        _PickOption(
            value: 3,
            icon: Icons.format_list_numbered,
            title: '3 transaksi'),
        _PickOption(
            value: 5,
            icon: Icons.format_list_numbered,
            title: '5 transaksi'),
        _PickOption(
            value: 10,
            icon: Icons.format_list_numbered,
            title: '10 transaksi'),
      ],
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Uang yang sudah kamu pegang sebelum mulai mencatat. '
                  'Ditambahkan ke saldo.'),
              const SizedBox(height: AppSpacing.s12),
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

  // ---------- Nama sapaan ----------

  Future<void> editDisplayName() async {
    final current = ref.read(displayNameProvider).value ?? '';
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nama sapaan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Muncul di sapaan Beranda, mis. “Selamat pagi, ReWin”. '
                  'Kosongkan untuk ikut nama akun Google; tanpa nama pun '
                  'tetap disapa (“Selamat pagi”).'),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'cth. ReWin',
                ),
              ),
            ],
          ),
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
      await ref.read(settingsServiceProvider).setDisplayName(ctrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama sapaan disimpan.')),
        );
      }
    }
  }

  // ---------- Kunci aplikasi ----------

  Future<void> pickLock() async {
    final current = ref.read(appLockProvider).value ?? 'none';
    final bioAvailable = await LockService.canUseBiometric();
    if (!mounted) return;
    final picked = await _pickSingle<String>(
      title: 'Kunci aplikasi',
      groupValue: current,
      options: [
        const _PickOption(
            value: 'none',
            icon: Icons.lock_open_outlined,
            title: 'Mati',
            subtitle: 'Buka langsung tanpa kunci'),
        const _PickOption(
            value: 'pin',
            icon: Icons.pin_outlined,
            title: 'PIN (6 digit)',
            subtitle: 'Minta PIN setiap buka aplikasi'),
        _PickOption(
            value: 'biometric',
            icon: Icons.fingerprint,
            title: 'Biometrik (sidik jari / wajah)',
            subtitle: bioAvailable
                ? 'PIN tetap jadi cadangan'
                : 'Tidak tersedia di HP ini',
            enabled: bioAvailable),
      ],
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
  /// Pesan validasi sama seperti sebelumnya, ditampilkan inline di dialog.
  Future<bool> setupPin() async {
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Buat PIN (6 digit)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  controller: second,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Ulangi PIN',
                    errorText: error,
                  ),
                  onSubmitted: (_) =>
                      Navigator.pop(c, true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () {
                  if (first.text.trim().length < 4) {
                    setS(() =>
                        error = 'PIN minimal 4 digit.');
                    return;
                  }
                  if (first.text.trim() !=
                      second.text.trim()) {
                    setS(() => error =
                        'PIN tidak sama, ulangi lagi.');
                    return;
                  }
                  Navigator.pop(c, true);
                },
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return false;
    // Pemeriksaan ulang (jaga-jaga bila dialog ditutup via submit):
    // pesan & aturan sama.
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
    // v1.43.0: isi CSV + tulis file + share pindah ke [ExportService]
    // (murni & bisa dites tanpa widget). Di sini cuma terjemahan hasil.
    try {
      final res = await ExportService.exportTransactionsCsv(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV dibuat: ${res.rows} baris.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export CSV gagal — coba lagi.')),
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

  /// Export PDF laporan bulan aktif (laporan = bulan yang dipilih di
  /// Beranda/Laporan). 100% lokal via `ReportPdfService`, tanpa server.
  /// Tanya Simpan-file vs Bagikan dulu — sama kayak pola tombol di Laporan.
  Future<void> exportMonthPdf() async {
    final month = ref.read(selectedMonthProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Bagikan PDF'),
              subtitle: Text('Laporan bulan $month'),
              onTap: () => Navigator.pop(c, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Simpan ke file'),
              subtitle: const Text('Pilih folder sendiri'),
              onTap: () => Navigator.pop(c, 'save'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'save') {
        final uri =
            await ReportPdfService.saveMonthPdfToFile(ref, monthKey: month);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uri == null
                ? 'Simpan PDF dibatalkan.'
                : 'PDF laporan $month tersimpan.'),
          ),
        );
      } else {
        final count =
            await ReportPdfService.exportMonthPdf(ref, monthKey: month);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF $month dibuat: $count transaksi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export PDF gagal — coba lagi.')),
        );
      }
    }
  }

  Future<void> restoreDb() async {
    final src = await BackupService.pickRestoreFile();
    if (src == null || !mounted) return;
    await restoreFromPath(src);
  }

  /// Konfirmasi + restore dari path tertentu (v1.39.0).
  ///
  /// Dipakai dua pintu: [restoreDb] (file yang dipilih user lewat file
  /// picker) dan [restoreAuto] (salinan harian di folder app). Isi dialog
  /// dan urutan operasinya SENGAJA satu tempat — dua salinan teks
  /// konfirmasi yang berbeda adalah cara termudah membuat user salah paham
  /// bahwa salah satunya lebih aman.
  Future<void> restoreFromPath(String src) async {
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError,
              ),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // restoreFrom menutup koneksi sendiri (urutan path → close → copy).
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

  /// Tombol "Sekarang" di baris "Backup terakhir" (v1.39.0): tulis salinan
  /// ke folder backup otomatis, bukan dialog pilih folder. Jatah 20 jam
  /// sengaja dilewati — user menekan tombol berarti minta sekarang.
  Future<void> backupNow() async {
    final ok = await ref.read(autoBackupProvider).runNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Backup tersimpan di HP.'
            : 'Backup gagal — coba lagi.'),
      ),
    );
  }

  /// Pulihkan dari salinan harian (v1.39.0). Daftar file dibaca dari folder
  /// app, terbaru dulu; isi dialog konfirmasi sama dengan restore manual.
  Future<void> restoreAuto() async {
    final dir = await BackupService.autoBackupDir();
    final files = await BackupService.listAutoBackups(dir);
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Belum ada backup otomatis di HP ini.')),
      );
      return;
    }
    // Ukuran + waktu dibaca SEBELUM sheet tampil supaya tidak ada await
    // di dalam builder (setiap rebuild akan mengulang I/O).
    final entries = <({String path, String when, String meta})>[];
    for (final f in files) {
      final len = await f.length();
      final at = await f.lastModified();
      entries.add((
        path: f.path,
        when: formatDateTime(at),
        meta: formatBytes(len),
      ));
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 0, AppSpacing.page, AppSpacing.s8),
              child: Text('Pulihkan backup otomatis',
                  style: Theme.of(c).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in entries)
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: Text(e.when),
                      subtitle: Text('${e.meta} · tersimpan di HP'),
                      onTap: () => Navigator.pop(c, e.path),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await restoreFromPath(picked);
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError,
              ),
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
            const SizedBox(height: AppSpacing.s12),
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError,
              ),
              child: const Text('Hapus permanen')),
        ],
      ),
    );
    if (second != true || !mounted) return;
    try {
      // wipeAll menutup koneksi sendiri (urutan path → close → hapus).
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
  //
  // Changelog kini halaman penuh [ChangelogScreen] (dibuka dari
  // AboutSettingsPage) — bottom-sheet 85% v1.16.x dihapus: pola modal
  // salah untuk konten referensi panjang (konflik scroll-vs-drag-sheet),
  // badge TERBARU-nya menipu (i==0, bukan versi terinstall), tanpa
  // tanggal, tanpa hierarki baca.
}

/// Satu opsi dalam dialog pilih — gaya baris STEP 4.
class _PickOption<V> {
  const _PickOption({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
    this.previewSize,
    this.enabled = true,
  });

  final V value;
  final IconData icon;
  final String title;
  final String? subtitle;
  final double? previewSize;
  final bool enabled;
}

class _PickRow<V> extends StatelessWidget {
  const _PickRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PickOption<V> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = option;
    return Opacity(
      opacity: o.enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primaryContainer
                      : AppColors.subtleOf(context),
                  // v1.30: thumbnail opsi ikut token thumb.
                  borderRadius: AppRadius.thumbAll,
                ),
                alignment: Alignment.center,
                child: Icon(
                  o.icon,
                  size: 20,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : AppColors.mutedOf(context),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      o.title,
                      style: (o.previewSize != null
                              ? TextStyle(
                                  fontSize: o.previewSize)
                              : Theme.of(context)
                                  .textTheme
                                  .bodyMedium)
                          ?.copyWith(
                              fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (o.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.micro),
                      Text(
                        o.subtitle!,
                        style: AppType.secondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 22,
                color: selected
                    ? scheme.primary
                    : AppColors.mutedOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titik warna aksen kompak: dot 48 + label + indikator cek.
class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : AppColors.borderOf(context),
                  width: selected ? 3 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check,
                      size: 22, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              width: 64,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppType.secondary(context).copyWith(
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: selected
                      ? scheme.primary
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
