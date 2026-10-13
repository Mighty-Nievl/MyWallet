import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
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
      overrides: [
        selectedAccountProvider.overrideWith((_) => accountId),
      ],
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
                      onPressed: () => ref.invalidate(
                        accountBalanceProvider(accountId),
                      ),
                      child: const Text(
                        'Coba lagi',
                        style: TextStyle(color: white),
                      ),
                    ),
                    data: (b) => Text(
                      display.money(b),
                      style: AppType.balanceHero(
                        context,
                      ).copyWith(color: white),
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
                  SettingRow(
                    icon: Icons.add,
                    title: 'Catat di dompet ini',
                    subtitle: 'Form terbuka dgn dompet ini terpilih',
                    onTap: () => _go(
                      context,
                      TxFormScreen(
                        startAsExpense: true,
                        initialAccountId: accountId,
                      ),
                    ),
                  ),
                  SettingRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Riwayat',
                    subtitle: 'Semua transaksi dompet ini',
                    onTap: () => _go(
                      context,
                      const HistoryScreen(),
                    ),
                  ),
                  SettingRow(
                    icon: Icons.savings_outlined,
                    title: 'Budget',
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
                    onTap: () => TransferSheet.show(
                      context,
                      fromId: accountId,
                    ),
                  ),
                  SettingRow(
                    icon: Icons.bar_chart_outlined,
                    title: 'Laporan',
                    subtitle: 'Ringkasan dompet ini',
                    onTap: () => _go(context, const ReportsScreen()),
                  ),
                  SettingRow(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan dompet',
                    subtitle: 'Ganti nama, saldo awal, arsip',
                    onTap: () => _go(context, const AccountsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
                padding: EdgeInsets.only(
                  top: j == 0 ? 0 : AppSpacing.s8,
                ),
                child: TxTile(
                  tx: list[j],
                  showDate: true,
                  dense: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TxFormScreen(existing: list[j]),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
