import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/mesh_gradient.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../screens/accounts_screen.dart';
import '../screens/account_detail_screen.dart';

/// Carousel kartu dompet Beranda (v1.29): gantikan hero gabungan +
/// strip chip. Satu halaman = satu kartu = satu dompet; kartu tampil
/// = filter aktif ([selectedAccountProvider], dua arah).
///
/// Tiap kartu = mesh identitas v1.28 + label nama dompet + saldo
/// per-dompet ([accountBalanceProvider]) + CTA catat. Dots = indikator
/// halaman (v1.30): tiap dompet + kartu Kelola dapat 1 dot, tap dot =
/// lompat halaman; halaman TERAKHIR = kartu Kelola (gear, tap →
/// AccountsScreen); kosong (semua arsip) = empty-state + Kelola.
class AccountCarousel extends ConsumerStatefulWidget {
  const AccountCarousel({super.key});

  @override
  ConsumerState<AccountCarousel> createState() => _AccountCarouselState();
}

class _AccountCarouselState extends ConsumerState<AccountCarousel> {
  late final PageController _ctrl;
  bool _syncing = false;

  /// Halaman tampil terakhir (0..list.length; == list.length = Kelola).
  /// Dots = indikator halaman, jadi aktif-nya ikut ini, bukan filter.
  /// ([onPageChanged] selalu setState — termasuk halaman trailing —
  /// agar dot Kelola ikut menyala.)
  int _page = 0;

  /// Indeks filter pada build sebelumnya. Sync-back PageView (filter luar
  /// → halaman) hanya bereaksi terhadap PERUBAHAN filter, bukan posisi
  /// halaman — tanpa ini, geser ke kartu Kelola (filter tetap) langsung
  /// ditarik balik ke halaman filter (guard lama bandingkan page≠index).
  /// Init 0 = halaman awal PageController.
  int _prevIndex = 0;

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
              ref.read(selectedAccountProvider.notifier).state = list.first.id;
            }
          });
        }
        // Sync-back: PageView mengikuti filter HANYA bila filter berubah
        // (dipilih dari luar/pick). Geser user (termasuk ke trailing
        // Kelola, yg filter-nya tetap) tak boleh ditarik balik.
        final filterChanged = _prevIndex != index;
        _prevIndex = index;
        if (_ctrl.hasClients &&
            filterChanged &&
            (_ctrl.page?.round() ?? -1) != index &&
            !_syncing) {
          final target = index;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _ctrl.hasClients) _ctrl.jumpToPage(target);
          });
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // v1.32: 264→188 (CTA 52 + spacer 24 hilang, kartu fokus
              // saldo; audit ulang via rect bila disentuh lagi).
              height: 188,
              child: PageView.builder(
                key: const ValueKey('home:carousel'),
                controller: _ctrl,
                onPageChanged: (i) {
                  // Lacak halaman tampil utk dots (termasuk trailing).
                  // Filter hanya berubah utk halaman dompet.
                  setState(() => _page = i);
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
            // Dots = indikator HALAMAN (v1.30): tiap dompet + kartu
            // Kelola trailing dapat 1 dot. Tap dot = lompat halaman
            // (filter ikut onPageChanged yg sudah guard trailing).
            Row(
              key: const ValueKey('home:dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(
                  list.length + 1,
                  (i) => Padding(
                    key: ValueKey(
                      i < list.length ? 'home:dots-$i' : 'home:dots-manage',
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _ctrl.jumpToPage(i);
                      },
                      child: Padding(
                        // Hit-area 24px (dot visual tetap 6px).
                        padding: const EdgeInsets.all(9),
                        child: _Dot(active: i == _page.clamp(0, list.length)),
                      ),
                    ),
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
/// v1.32: tap kartu → [AccountDetailScreen] (request user — detail
/// dompet: saldo, riwayat, budget, utang, struk, pindah dana, laporan,
/// pengaturan). Mata toggle tetap overlay (tap-nya tak buka detail).
class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final balance = ref.watch(accountBalanceProvider(account.id));
    const white = Colors.white;

    // v1.32: tap kartu → detail dompet (request user). [_TapToOpen]
    // pakai Listener mentah (tak ikut gesture arena) agar drag PageView
    // bebas; tap = down+up dalam slop. Splash dikorbankan; haptic +
    // navigasi langsung = feedback.
    // Key di Container (bukan MeshGradient): PageView ikut hit-test ke
    // key anak — key di MeshGradient membuat finder key mengembalikan
    // PageView (rect viewport penuh) sehingga tap/test salah sasaran
    // (terbukti probe rect: key di MeshGradient = rect 0,0,390,188).
    return Container(
      key: ValueKey('home:card-${account.id}'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      child: Semantics(
        button: true,
        label: 'Detail dompet ${account.name}',
        child: _TapToOpen(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(accountId: account.id),
              ),
            );
          },
          child: MeshGradient(
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
                            onPressed: () => ref.invalidate(
                              accountBalanceProvider(account.id),
                            ),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                      data: (b) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hide ? 'Rp••••••' : display.money(b),
                          style: AppType.balanceHero(
                            context,
                          ).copyWith(color: white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // kartu fokus saldo; pintu catat = tombol + navbar, grid aksi,
                    // scan). Spacer s24 ikut dibuang agar kartu ramping.
                  ],
                ),
                // Mata toggle overlay kanan-atas (bukan sebaris nama):
                // hemat 33px tinggi baris → kartu muat viewport 188px.
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
          ),
        ),
      ),
    );
  }
}

/// Tap-tanpa-arena untuk kartu di dalam PageView (v1.32).
///
/// [Listener] mentah tak mendaftarkan recognizer → gesture arena
/// PageView tak terganggu (drag bebas). Tap = down+up dalam slop 18px
/// tanpa gerakan berlebih; geser = pointer bergerak jauh → onTap tak
/// fire. Mata toggle (AppIconButton di dalam) tetap terima tap-nya
/// sendiri karena hit-test anak lebih dulu; Listener induk hanya catat
/// posisi.
class _TapToOpen extends StatefulWidget {
  const _TapToOpen({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapToOpen> createState() => _TapToOpenState();
}

class _TapToOpenState extends State<_TapToOpen> {
  Offset? _down;

  /// Batas gerak tap (= kTouchSlop 18 + 8 toleransi; konstanta lokal agar
  /// tak tambah import gestures hanya untuk ini).
  static const _slop = 26.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _down = e.position,
      onPointerMove: (e) {
        // Geser jauh = bukan tap (batalkan; PageView yang tangani).
        if (_down != null && (e.position - _down!).distance > _slop) {
          _down = null;
        }
      },
      onPointerUp: (e) {
        final d = _down;
        _down = null;
        if (d != null && (e.position - d).distance <= _slop) {
          widget.onTap();
        }
      },
      onPointerCancel: (_) => _down = null,
      child: widget.child,
    );
  }
}

/// Halaman TERAKHIR carousel (v1.29.1): kartu Kelola bergambar gear.
/// v1.30: BINGKAI disamakan dgn [_WalletCard] (margin + padding + shadow
/// + radius sama; isi Column atas→bawah + CTA 52px di bawah) agar tak
/// ada lompat vertikal saat geser ke ujung. Outline netral (bukan mesh)
/// agar terbaca sebagai AKSI; dots = indikator halaman (dapat 1 dot).
class _ManageCard extends StatelessWidget {
  const _ManageCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Dua jalur tap alami (area kartu via InkWell + CTA via FilledButton);
    // tanpa Semantics luar agar CTA tetap terbaca screen reader.
    return Container(
      key: const ValueKey('home:card-manage'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      padding: AppSpacing.cardPaddingLarge,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppShadows.card(context),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AccountsScreen()));
        },
        borderRadius: AppRadius.cardAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
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
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelola dompet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Tambah, susun, arsipkan',
                        style: AppType.secondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // v1.32: CTA "Buka kelola" DIHAPUS (konsisten dgn CTA kartu
            // saldo; tap kartu = kelola, parity tinggi terjaga via
            // mainAxisAlignment.center).
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
