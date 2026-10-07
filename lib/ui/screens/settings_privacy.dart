import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../format.dart';
import 'settings_actions.dart';

/// Sub-halaman Saldo & Privasi: sembunyikan + cakupan, saldo awal,
/// kunci aplikasi, pengingat harian.
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

  bool _match(String title, String subtitle, [List<String> keys = const []]) {
    if (_q.isEmpty) return true;
    final hay = '$title $subtitle ${keys.join(' ')}'.toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final hideBalance = ref.watch(hideBalanceProvider);
    final privacyScope = ref.watch(privacyScopeProvider);
    final starting = ref.watch(startingBalanceProvider);
    final appLock = ref.watch(appLockProvider);
    final reminder = ref.watch(reminderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saldo & Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari di Saldo & Privasi…',
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
                if (_match('sembunyikan', 'privacy', const ['hide']))
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off),
                    title: const Text('Sembunyikan saldo'),
                    subtitle: Text(privacyScope.when(
                      loading: () => 'Nominal jadi Rp••••',
                      error: (_, _) => 'Nominal jadi Rp••••',
                      data: (s) => s == 'all'
                          ? 'Semua nominal jadi Rp••••'
                          : 'Nominal jadi Rp•••• di Beranda',
                    )),
                    value: hideBalance.value ?? false,
                    onChanged: (v) => ref
                        .read(settingsServiceProvider)
                        .setHideBalance(v),
                  ),
                if ((hideBalance.value ?? false) &&
                    _match('cakupan', 'semua nominal', const ['scope']))
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Cakupan sembunyikan'),
                    subtitle: Text(privacyScope.when(
                      loading: () => '…',
                      error: (_, _) => 'Gagal memuat',
                      data: (s) => s == 'all'
                          ? 'Semua nominal (saldo + list + laporan)'
                          : 'Hanya saldo Beranda',
                    )),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: pickPrivacyScope,
                  ),
                if (_match('saldo awal', 'uang mulai', const ['balance']))
                  const Divider(height: 1),
                if (_match('saldo awal', 'uang mulai', const ['balance']))
                  ListTile(
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
                    onTap: editStartingBalance,
                  ),
                if (_match('kunci', 'pin biometrik', const ['lock']))
                  const Divider(height: 1),
                if (_match('kunci', 'pin biometrik', const ['lock']))
                  ListTile(
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
                    onTap: pickLock,
                  ),
                if (_match('pengingat', 'notifikasi', const ['reminder']))
                  const Divider(height: 1),
                if (_match('pengingat', 'notifikasi', const ['reminder']))
                  reminder.when(
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
                              ? 'Setiap hari pukul ${hhmm(r.hour, r.minute)}'
                              : 'Mati'),
                          value: r.enabled,
                          onChanged: (v) =>
                              toggleReminder(v, r.hour, r.minute),
                        ),
                        if (r.enabled)
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Jam pengingat'),
                            subtitle: Text(hhmm(r.hour, r.minute)),
                            trailing: const Icon(Icons.edit),
                            onTap: pickReminderTime,
                          ),
                      ],
                    ),
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
