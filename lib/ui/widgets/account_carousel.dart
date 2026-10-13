import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/mesh_gradient.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../screens/accounts_screen.dart';
import '../screens/tx_form_screen.dart';

/// Carousel kartu dompet Beranda (v1.29): gantikan hero gabungan +
/// strip chip. Satu halaman = satu kartu = satu dompet; kartu tampil
/// = filter aktif ([selectedAccountProvider], dua arah).
///
/// Tiap kartu = mesh identitas v1.28 + label nama dompet + saldo
/// per-dompet ([accountBalanceProvider]) + CTA catat. Dots sembunyi
/// saat 1 dompet; halaman TERAKHIR = kartu Kelola (gear, tap →
/// AccountsScreen); kosong (semua arsip) = empty-state + Kelola.
class AccountCarousel extends ConsumerStatefulWidget {
  const AccountCarousel({super.key});

  @override
  ConsumerState<AccountCarousel> createState() => _AccountCarouselState();
}

class _AccountCarouselState extends ConsumerState<AccountCarousel> {
  late final PageController _ctrl;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pick(int id) {
    HapticFeedback.selectionClick();
    ref.read(selectedAccountProvider.notifier).state = id;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final selected = ref.watch(selectedAccountProvider);
    return accounts.when(
      loading: () => const AppSkeleton(lines: 1),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(accountsProvider),
          child: const Text('Coba lagi'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '👛',
            title: 'Belum ada dompet',
            subtitle: 'Tambah dompet pertama lewat Kelola.',
          );
        }
        var index = list.indexWhere((a) => a.id == selected);
        if (index < 0) {
          index = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(selectedAccountProvider.notifier).state =
                  list.first.id;
            }
          });
        }
        if (_ctrl.hasClients &&
            (_ctrl.page?.round() ?? -1) != index &&
            !_syncing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _ctrl.hasClients) _ctrl.jumpToPage(index);
          });
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 264,
              child: PageView.builder(
                key: const ValueKey('home:carousel'),
                controller: _ctrl,
                onPageChanged: (i) {
                  // Halaman trailing = kartu Kelola (bukan dompet) —
                  // filter tidak berubah.
                  if (i >= list.length) return;
                  _syncing = true;
                  _pick(list[i].id);
                  _syncing = false;
                },
                itemCount: list.length + 1,
                itemBuilder: (_, i) => i < list.length
                    ? _WalletCard(account: list[i])
                    : const _ManageCard(),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            // Dots = status filter per-dompet (kartu Kelola trailing
            // tak punya dot — ia aksi, bukan filter).
            Row(
              key: const ValueKey('home:dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (list.length > 1)
                  ...List.generate(
                    list.length,
                    (i) => Padding(
                      key: ValueKey('home:dots-$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Dot(active: i == index),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Satu kartu dompet: salin isi hero mesh (_HeroCard) + label nama.
/// Saldo = [accountBalanceProvider] (per-dompet, bukan gabungan).
class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final balance = ref.watch(accountBalanceProvider(account.id));
    const white = Colors.white;

    return MeshGradient(
      key: ValueKey('home:card-${account.id}'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      padding: AppSpacing.cardPaddingLarge,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama dompet (sisakan 48px kanan untuk mata overlay).
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Text(
                  account.name,
                  style: AppType.labelMuted(context).copyWith(
                    letterSpacing: 0.8,
                    color: white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
            'SALDO SAAT INI',
            style: AppType.labelMuted(context).copyWith(
              letterSpacing: 0.8,
              color: white.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s12),
          balance.when(
            loading: () => const AppSkeleton(lines: 1),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo gagal dimuat.',
                  style: AppType.balance(
                    context,
                  ).copyWith(fontSize: 20, color: white),
                ),
                const SizedBox(height: AppSpacing.s8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(accountBalanceProvider(account.id)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
            data: (b) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hide ? 'Rp••••••' : display.money(b),
                style: AppType.balanceHero(context).copyWith(color: white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.ctaHeight,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TxFormScreen(startAsExpense: true),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                '+ Catat keluar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ],
          ),
          // Mata toggle overlay kanan-atas (bukan sebaris nama):
          // hemat 33px tinggi baris → kartu muat viewport 264px.
          Positioned(
            top: 0,
            right: 0,
            child: AppIconButton(
              icon: hide
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
              color: white.withValues(alpha: 0.92),
              bordered: false,
              onPressed: () =>
                  ref.read(settingsServiceProvider).setHideBalance(!hide),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman TERAKHIR carousel (v1.29.1): kartu Kelola bergambar gear.
/// Tap → [AccountsScreen]. Outline netral (bukan mesh) agar terbaca
/// sebagai AKSI, bukan dompet — dan tak punya dot (dots = filter).
class _ManageCard extends StatelessWidget {
  const _ManageCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('home:card-manage'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountsScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
          side: BorderSide(color: scheme.outlineVariant),
          padding: AppSpacing.cardPaddingLarge,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Kelola dompet',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: 28,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Kelola dompet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Tambah, susun, arsipkan',
              style: AppType.secondary(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }
}
