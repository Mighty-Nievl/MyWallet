import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../format.dart';
import 'settings_actions.dart';

/// Sub-halaman Saldo & Privasi: sembunyikan + cakupan, saldo awal,
/// kunci aplikasi, pengingat harian.
///
/// STEP 4 — hanya presentasi yang diubah. Semua provider, setter,
/// dialog (via [SettingsActions]), filter cari, dan nilai TETAP.
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

    String scopeLabel(String s) => s == 'all'
        ? 'Semua nominal (saldo + list + laporan)'
        : 'Hanya saldo Beranda';
    String lockLabel(String m) => switch (m) {
          'pin' => 'PIN',
          'biometric' => 'Biometrik',
          _ => 'Mati',
        };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: 'Saldo & Privasi'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  96,
                ),
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
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SettingsGroup(
                    title: 'Saldo',
                    children: [
                      if (_match('sembunyikan', 'privacy', const ['hide']))
                        SettingRow(
                          icon: Icons.visibility_off_outlined,
                          title: 'Sembunyikan saldo',
                          subtitle: privacyScope.when(
                            loading: () => 'Nominal jadi Rp••••',
                            error: (_, _) => 'Nominal jadi Rp••••',
                            data: (s) => s == 'all'
                                ? 'Semua nominal jadi Rp••••'
                                : 'Nominal jadi Rp•••• di Beranda',
                          ),
                          trailing: Switch(
                            value: hideBalance.value ?? false,
                            onChanged: (v) => ref
                                .read(settingsServiceProvider)
                                .setHideBalance(v),
                          ),
                          onTap: () => ref
                              .read(settingsServiceProvider)
                              .setHideBalance(
                                  !(hideBalance.value ?? false)),
                        ),
                      if ((hideBalance.value ?? false) &&
                          _match('cakupan', 'semua nominal', const ['scope']))
                        SettingRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Cakupan sembunyikan',
                          subtitle: privacyScope.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: scopeLabel,
                          ),
                          trailing: SettingValue(
                            value: privacyScope.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: (s) =>
                                  s == 'all' ? 'Semua' : 'Saldo',
                            ),
                          ),
                          onTap: pickPrivacyScope,
                        ),
                      if (_match('saldo awal', 'uang mulai', const ['balance']))
                        SettingRow(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Saldo awal',
                          subtitle: starting.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: (s) => s == 0
                                ? 'Belum diatur (mulai dari Rp0)'
                                : formatRp(s),
                          ),
                          trailing: SettingValue(
                            value: starting.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: (s) =>
                                  s == 0 ? 'Atur' : formatRp(s),
                            ),
                          ),
                          onTap: editStartingBalance,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SettingsGroup(
                    title: 'Keamanan',
                    children: [
                      if (_match('kunci', 'pin biometrik', const ['lock']))
                        SettingRow(
                          icon: Icons.lock_outlined,
                          title: 'Kunci aplikasi',
                          subtitle: appLock.when(
                            loading: () => '…',
                            error: (_, _) => 'Gagal memuat',
                            data: lockLabel,
                          ),
                          trailing: SettingValue(
                            value: appLock.when(
                              loading: () => '…',
                              error: (_, _) => '…',
                              data: lockLabel,
                            ),
                          ),
                          onTap: pickLock,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SettingsGroup(
                    title: 'Pengingat',
                    children: [
                      if (_match('pengingat', 'notifikasi', const ['reminder']))
                        reminder.when(
                          loading: () => const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator()),
                          error: (_, _) => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'Gagal memuat pengaturan pengingat.')),
                          data: (r) => Column(
                            children: [
                              SettingRow(
                                icon: Icons.notifications_outlined,
                                title: 'Ingatkan mencatat',
                                subtitle: r.enabled
                                    ? 'Setiap hari pukul ${hhmm(r.hour, r.minute)}'
                                    : 'Mati',
                                trailing: Switch(
                                  value: r.enabled,
                                  onChanged: (v) => toggleReminder(
                                      v, r.hour, r.minute),
                                ),
                                onTap: () => toggleReminder(
                                    !r.enabled, r.hour, r.minute),
                              ),
                              if (r.enabled)
                                SettingRow(
                                  icon: Icons.schedule,
                                  title: 'Jam pengingat',
                                  subtitle: hhmm(r.hour, r.minute),
                                  trailing: SettingValue(
                                    value:
                                        hhmm(r.hour, r.minute),
                                  ),
                                  onTap: pickReminderTime,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
