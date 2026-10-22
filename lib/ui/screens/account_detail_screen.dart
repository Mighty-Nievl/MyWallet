import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/account_actions.dart';
import '../../data/auth_service.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/sync_meta.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_header.dart';
import '../components/app_section.dart';
import '../components/mesh_gradient.dart';
import '../components/setting_row.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../scan_flow.dart';
import '../transaction_actions.dart';
import '../widgets/tx_tile.dart';
import 'accounts_screen.dart';
import 'budget_screen.dart';
import 'debt_screen.dart';
import 'history_screen.dart';
import 'reports_screen.dart';
import 'tx_form_screen.dart';

/// Detail satu dompet (v1.32, request user): tap kartu saldo Beranda →
///
/// - Hero mesh: nama + saldo dompet itu (bukan gabungan).
/// - "Terakhir di dompet ini": 5 transaksi terakhir dompet itu
///   (watchHistory accountId, TxTile tanpa chevron).
/// - Menu jalan pintas scoped dompet: Riwayat, Budget, Utang-piutang,
///   Scan struk, Pindah dana, Laporan, pengaturan (Kelola → menu dompet).
///
/// Pintasan scoped via override [selectedAccountProvider] = id dompet
/// (sementara selama layar hidup; kembali = filter semula). Tanpa ini
/// layar tujuan ikut filter global Beranda (salah dompet bila user
/// geser carousel lalu buka detail tanpa tap kartu).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return ProviderScope(
      overrides: [selectedAccountProvider.overrideWith((_) => accountId)],
      child: _Body(accountId: accountId, accounts: accounts),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.accountId, required this.accounts});

  final int accountId;
  final AsyncValue<List<Account>> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name =
        accounts.value?.where((a) => a.id == accountId).firstOrNull?.name ??
        'Dompet';
    final balance = ref.watch(accountBalanceProvider(accountId));
    final display = ref.watch(displayPrefsProvider);
    const white = Colors.white;

    return Scaffold(
      // v1.32.1 (request user): Catat = FAB, bukan baris menu — tombol
      // + selalu terlihat walau daftar digulir; buka form dgn dompet
      // ini terpilih (initialAccountId).
      floatingActionButton: FloatingActionButton(
        key: ValueKey('detail:fab-$accountId'),
        tooltip: 'Catat di $name',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TxFormScreen(
                startAsExpense: true,
                initialAccountId: accountId,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            AppSpacing.bottomPad,
          ),
          children: [
            AppHeader(title: name, onBack: Navigator.of(context).pop),
            const SizedBox(height: AppSpacing.s8),
            MeshGradient(
              key: ValueKey('detail:hero-$accountId'),
              padding: AppSpacing.cardPaddingLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALDO SAAT INI',
                    style: AppType.labelMuted(context).copyWith(
                      letterSpacing: 0.8,
                      color: white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  balance.when(
                    loading: () => const AppSkeleton(lines: 1),
                    error: (_, _) => TextButton(
                      onPressed: () =>
                          ref.invalidate(accountBalanceProvider(accountId)),
                      child: const Text(
                        'Coba lagi',
                        style: TextStyle(color: white),
                      ),
                    ),
                    data: (b) => Text(
                      display.money(b),
                      style: AppType.balanceHero(context)
                          .copyWith(color: white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppSection(
              title: 'Terakhir di dompet ini',
              child: _AccountRecent(accountId: accountId),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppSection(
              title: 'Kelola ${name.isEmpty ? 'dompet' : '“$name”'}',
              child: Column(
                children: [
                  // v1.32.1: baris 'Catat di dompet ini' HAPUS — tugasnya
                  // pindah ke FAB (request user); menu = navigasi murni.
                  SettingRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Riwayat',
                    subtitle: 'Semua transaksi dompet ini',
                    onTap: () => _go(context, const HistoryScreen()),
                  ),
                  SettingRow(
                    icon: Icons.savings_outlined,
                    title: 'Anggaran',
                    subtitle: 'Batas per kategori dompet ini',
                    onTap: () => _go(context, const BudgetScreen()),
                  ),
                  SettingRow(
                    icon: Icons.handshake_outlined,
                    title: 'Utang & piutang',
                    subtitle: 'Pinjaman dompet ini',
                    onTap: () => _go(context, const DebtScreen()),
                  ),
                  SettingRow(
                    icon: Icons.document_scanner_outlined,
                    title: 'Scan struk',
                    subtitle: 'Simpan ke dompet ini',
                    onTap: () => runScanFlow(context, ref),
                  ),
                  SettingRow(
                    icon: Icons.swap_horiz,
                    title: 'Pindah dana',
                    subtitle: 'Transfer dari dompet ini',
                    onTap: () => TransferSheet.show(context, fromId: accountId),
                  ),
                  SettingRow(
                    icon: Icons.bar_chart_outlined,
                    title: 'Laporan',
                    subtitle: 'Ringkasan dompet ini',
                    onTap: () => _go(context, const ReportsScreen()),
                  ),
                  // v1.32: baris 'Pengaturan dompet' HAPUS — diganti seksi
                  // Pengaturan di bawah (ganti nama + saldo awal + toggle
                  // keluarga + arsip, fokus 1 dompet; bukan layar Kelola).
                ],
              ),
            ),
            // v1.32: SEKSI PENGATURAN dompet (request user): ganti nama,
            // saldo awal, arsip, + toggle keluarga (isShared). Kembali =
            // pop (bukan layar AccountsScreen penuh — fokus 1 dompet).
            AppSection(
              title: 'Pengaturan',
              child: Column(
                children: [
                  SettingRow(
                    icon: Icons.drive_file_rename_outline,
                    title: 'Ganti nama',
                    subtitle: name.isEmpty ? 'Beri nama dompet ini' : name,
                    onTap: () => _renameSheet(context, ref),
                  ),
                  SettingRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Saldo awal',
                    subtitle: _openingText(ref),
                    onTap: () => _openingSheet(context, ref),
                  ),
                  _SharedToggle(accountId: accountId, accounts: accounts),
                  SettingRow(
                    icon: Icons.archive_outlined,
                    title: 'Arsipkan dompet',
                    subtitle: 'Sembunyikan dari Beranda, riwayat tetap ada',
                    onTap: () => _confirmArchive(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teks saldo awal utk subtitle (baca sekali, tanpa watch).
  String _openingText(WidgetRef ref) {
    final acc = accounts.value?.where((a) => a.id == accountId).firstOrNull;
    if (acc == null) return 'Belum diatur';
    final display = ref.read(displayPrefsProvider);
    return display.money(acc.openingBalance);
  }

  /// Sheet ganti nama (pola _NameSheet Kelola: keyboard-safe).
  Future<void> _renameSheet(BuildContext context, WidgetRef ref) async {
    final acc = accounts.value?.where((a) => a.id == accountId).firstOrNull;
    final ctrl = TextEditingController(text: acc?.name ?? '');
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.sectionGap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ganti nama dompet', style: AppType.sectionTitle(context)),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    hintText: 'cth. Pribadi, Keluarga, Darurat',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
                ),
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  height: AppSpacing.ctaHeight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    await (ref.read(dbProvider).update(ref.read(dbProvider).accounts)
          ..where((a) => a.id.equals(accountId)))
        .write(
          AccountsCompanion(
            name: Value(name.trim()),
            updatedAt: Value(syncNow()),
          ),
        );
  }

  /// Sheet saldo awal (angka rupiah; ikut hitung saldo dompet ini).
  Future<void> _openingSheet(BuildContext context, WidgetRef ref) async {
    final acc = accounts.value?.where((a) => a.id == accountId).firstOrNull;
    final ctrl = TextEditingController(
      text: acc == null || acc.openingBalance == 0
          ? ''
          : acc.openingBalance.toString(),
    );
    final raw = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.sectionGap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Saldo awal', style: AppType.sectionTitle(context)),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'cth. 500000',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
                ),
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  height: AppSpacing.ctaHeight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (raw == null) return;
    final amount = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    HapticFeedback.lightImpact();
    await (ref.read(dbProvider).update(ref.read(dbProvider).accounts)
          ..where((a) => a.id.equals(accountId)))
        .write(
          AccountsCompanion(
            openingBalance: Value(amount),
            updatedAt: Value(syncNow()),
          ),
        );
  }

  /// Konfirmasi arsip (pola Kelola: arsip selalu boleh, riwayat aman).
  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Arsipkan dompet?'),
        content: const Text(
          'Dompet hilang dari Beranda, tapi riwayat transaksinya tetap '
          'ada di gabungan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    HapticFeedback.selectionClick();
    await archiveAccount(ref.read(dbProvider), accountId);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _go(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

/// Toggle keluarga per-dompet (v1.32, request user).
///
/// ON = dompet dishare ke rumah tangga (ikut push/pull sync); OFF =
/// pribadi (hanya HP ini). Tulis `isShared + updatedAt` agar LWW
/// merambatkan keputusan ke HP lain. Tanpa rumah tangga (belum
/// gabung) = toggle tetap bisa diatur (tersimpan lokal, berlaku saat
/// sync pertama) — subtitle jujur menyebut statusnya.
class _SharedToggle extends ConsumerWidget {
  const _SharedToggle({required this.accountId, required this.accounts});

  final int accountId;
  final AsyncValue<List<Account>> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared =
        accounts.value?.where((a) => a.id == accountId).firstOrNull?.isShared ??
        false;
    final session = ref.watch(familySessionProvider);
    final inHousehold =
        session.value?.householdId != null &&
        (session.value?.householdId ?? '').isNotEmpty;
    return SettingRow(
      icon: Icons.group_outlined,
      title: 'Dikelola keluarga',
      subtitle: shared
          ? (inHousehold
                ? 'Keluarga — dompet + transaksinya ikut Sync'
                : 'Akan ikut Sync setelah gabung rumah tangga')
          : 'Pribadi — tidak dikirim ke rumah tangga',
      trailing: Switch(
        key: ValueKey('detail:shared-$accountId'),
        value: shared,
        onChanged: (v) async {
          HapticFeedback.selectionClick();
          if (shared && !v) {
            final yes = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Jadikan pribadi?'),
                content: const Text(
                  'Dompet ini tidak akan dikirim pada Sync berikutnya. '
                  'Data yang sudah terlanjur tersinkron tetap ada di HP '
                  'anggota lain — hapus manual bila perlu.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Jadikan pribadi'),
                  ),
                ],
              ),
            );
            if (yes != true) return;
          }
          await (ref.read(dbProvider).update(ref.read(dbProvider).accounts)
                ..where((a) => a.id.equals(accountId)))
              .write(
                AccountsCompanion(
                  isShared: Value(v),
                  updatedAt: Value(syncNow()),
                ),
              );
        },
      ),
    );
  }
}

/// 5 transaksi terakhir SATU dompet (cermin _RecentList Beranda, tanpa
/// grup tanggal — layar detail sudah scoped, header grup = noise).
class _AccountRecent extends ConsumerWidget {
  const _AccountRecent({required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return StreamBuilder<List<TxWithCategory>>(
      stream: db.watchHistory(limit: 5, accountId: accountId),
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppErrorState(title: 'Transaksi gagal dimuat.');
        }
        if (!snap.hasData) return const AppSkeleton(lines: 3);
        final list = snap.data!;
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '💸',
            title: 'Belum ada transaksi',
            subtitle: 'Catat pertama di dompet ini lewat tombol +.',
          );
        }
        return Column(
          children: [
            for (var j = 0; j < list.length; j++)
              Padding(
                padding: EdgeInsets.only(top: j == 0 ? 0 : AppSpacing.s8),
                child: TxTile(
                  tx: list[j],
                  showDate: true,
                  dense: true,
                  onTap: () => openTransaction(context, ref, list[j]),
                ),
              ),
          ],
        );
      },
    );
  }
}
