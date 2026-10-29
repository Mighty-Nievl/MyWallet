import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../components/setting_row.dart';
import '../components/settings_scaffold.dart';
import '../design/app_spacing.dart';
import '../format.dart';
import 'settings_actions.dart';
import 'settings_catalog.dart';

/// Sub-halaman Saldo, Privasi & Pengingat: sembunyikan + cakupan, saldo awal,
/// kunci aplikasi, pengingat harian.
///
/// v1.43.0: kerangka [SettingsScaffold], switch [SettingSwitch], filter dari
/// [SettingsCatalog]. Nilai provider dibaca lewat `.value ?? default` —
/// dulu tiap baris punya cabang loading/error sendiri sampai 20 tempat dan
/// gagal baca prefs berakhir "…" permanen tanpa cara pulih.
class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage>
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
    final hideBalance = ref.watch(hideBalanceProvider).value ?? false;
    final privacyScope = ref.watch(privacyScopeProvider).value ?? 'balance';
    final starting = ref.watch(startingBalanceProvider).value;
    final appLock = ref.watch(appLockProvider).value ?? 'none';
    final reminder =
        ref.watch(reminderProvider).value ??
        (enabled: false, hour: 20, minute: 0);
    final service = ref.read(settingsServiceProvider);

    String lockLabel(String m) => switch (m) {
      'pin' => 'PIN',
      'biometric' => 'Biometrik',
      _ => 'Mati',
    };

    return SettingsScaffold(
      title: 'Saldo, Privasi & Pengingat',
      search: SettingsSearchField(
        controller: _searchCtrl,
        hint: 'Cari di pengaturan ini…',
        query: _q,
        onChanged: (v) => setState(() => _q = v),
      ),
      children: [
        SettingsGroup(
          title: 'Saldo',
          children: [
            if (_show('sembunyikan-saldo'))
              SettingSwitch(
                icon: Icons.visibility_off_outlined,
                title: 'Sembunyikan saldo',
                subtitle: privacyScope == 'all'
                    ? 'Semua nominal jadi Rp••••'
                    : 'Nominal jadi Rp•••• di Beranda',
                value: hideBalance,
                onChanged: service.setHideBalance,
              ),
            // Cakupan tetap tampil walau "sembunyikan" mati: nilainya
            // tersimpan, dan menyembunyikannya membuat pencarian
            // ("cakupan") berakhir di halaman kosong.
            if (_show('cakupan'))
              SettingRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Cakupan sembunyikan',
                subtitle: privacyScope == 'all'
                    ? 'Semua nominal (saldo + list + laporan)'
                    : 'Hanya saldo Beranda',
                trailing: SettingValue(
                  value: privacyScope == 'all' ? 'Semua' : 'Saldo',
                ),
                onTap: pickPrivacyScope,
              ),
            if (_show('saldo-awal'))
              SettingRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Saldo awal',
                subtitle: starting == null
                    ? '…'
                    : (starting == 0
                          ? 'Belum diatur (mulai dari Rp0)'
                          : formatRp(starting)),
                trailing: SettingValue(
                  value: starting == null
                      ? '…'
                      : (starting == 0 ? 'Atur' : formatRp(starting)),
                ),
                onTap: editStartingBalance,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SettingsGroup(
          title: 'Keamanan',
          children: [
            if (_show('kunci-aplikasi'))
              SettingRow(
                icon: Icons.lock_outlined,
                title: 'Kunci aplikasi',
                subtitle: lockLabel(appLock),
                trailing: SettingValue(value: lockLabel(appLock)),
                onTap: pickLock,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SettingsGroup(
          title: 'Pengingat',
          children: [
            if (_show('pengingat'))
              SettingSwitch(
                icon: Icons.notifications_outlined,
                title: 'Ingatkan mencatat',
                subtitle: reminder.enabled
                    ? 'Setiap hari pukul ${hhmm(reminder.hour, reminder.minute)}'
                    : 'Mati',
                value: reminder.enabled,
                onChanged: (v) =>
                    toggleReminder(v, reminder.hour, reminder.minute),
              ),
            // Jam hanya relevan saat pengingat menyala — kecuali user
            // sedang mencari "jam": jangan beri halaman kosong.
            if ((reminder.enabled || _q.isNotEmpty) && _show('jam-pengingat'))
              SettingRow(
                icon: Icons.schedule,
                title: 'Jam pengingat',
                subtitle: hhmm(reminder.hour, reminder.minute),
                trailing: SettingValue(
                  value: hhmm(reminder.hour, reminder.minute),
                ),
                onTap: pickReminderTime,
              ),
          ],
        ),
      ],
    );
  }
}
