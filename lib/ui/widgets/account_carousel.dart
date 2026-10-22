import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/mesh_gradient.dart';
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
/// per-dompet ([accountBalanceProvider]). Dots = indikator halaman dan
/// hanya tampil bila dompet >1. v1.37: "Kelola dompet" keluar dari
/// PageView — ia aksi, bukan halaman data, jadi tak boleh menggeser
/// scope diam-diam. Kosong (semua arsip) = empty-state + tombol Kelola.
class AccountCarousel extends ConsumerStatefulWidget {
  const AccountCarousel({super.key});

  @override
  ConsumerState<AccountCarousel> createState() => _AccountCarouselState();
}

class _AccountCarouselState extends ConsumerState<AccountCarousel> {
  late final PageController _ctrl;
  bool _syncing = false;

  /// Halaman dompet yang sedang tampil (0..list.length-1).
  /// Dots = indikator halaman; halaman = filter aktif.
  int _page = 0;

  /// Indeks filter pada build sebelumnya. Sync-back PageView (filter luar
  /// → halaman) hanya bereaksi terhadap PERUBAHAN filter, bukan posisi
  /// halaman. Init 0 = halaman awal PageController.
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

  /// [id] null = "Semua dompet" (gabungan) — default provider.
  void _pick(int? id) {
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
          return AppEmptyState(
            icon: '👛',
            title: 'Belum ada dompet',
            subtitle: 'Tambah dompet pertama lewat Kelola.',
            action: TextButton.icon(
              key: const ValueKey('home:manage'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Kelola dompet'),
            ),
          );
        }
        // v1.38.0: "Semua dompet" jadi halaman 0 saat dompet >1. Gabungan
        // itulah default provider (`selectedAccountProvider` null = Semua),
        // tapi dulu UI memaksa pilih dompet pertama — jadi total semua uang
        // tak pernah punya tempat, padahal `balanceProvider` sudah
        // menghitungnya.
        final multi = list.length > 1;
        final pageCount = multi ? list.length + 1 : list.length;
        var index = 0;
        if (multi) {
          // index 0 = Semua; dompet ke-i jadi halaman i+1. id tak dikenal
          // (-1 + 1 = 0) jatuh ke Semua, bukan ke dompet acak.
          index = selected == null ? 0 : list.indexWhere((a) => a.id == selected) + 1;
          if (index < 0) index = 0;
        } else if (selected != list.first.id) {
          // Satu dompet: pertahankan perilaku lama (pilih dompet itu) supaya
          // Kelola tetap menyorot satu baris. Angkanya identik dengan Semua.
          index = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(selectedAccountProvider.notifier).state = list.first.id;
            }
          });
        }
        // Sync-back: PageView mengikuti filter HANYA bila filter berubah
        // (dipilih dari luar/pick). Geser user tak boleh ditarik balik.
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
                  setState(() => _page = i);
                  _syncing = true;
                  _pick(
                    multi ? (i == 0 ? null : list[i - 1].id) : list.first.id,
                  );
                  _syncing = false;
                },
                itemCount: pageCount,
                itemBuilder: (_, i) => multi
                    ? (i == 0
                          ? _AllWalletsCard(count: list.length)
                          : _WalletCard(account: list[i - 1]))
                    : _WalletCard(account: list.first),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            // v1.37.1: indikator halaman sendirian di kiri, aksi Kelola di
            // kanan — pola section header (konten + trailing), bukan satu
            // baris center yang mencampur paginasi dengan pengaturan.
            //
            // Pitch: slot 28×32. Target 48px (touchMin) terbukti merusak
            // pitch — celah antar dot jadi 42px sehingga dua titik 6px
            // terbaca nyasar. 28×32 masih di atas minimum WCAG 2.2 AA
            // (24×24) dan mis-tap antar dompet murah (tinggal geser lagi).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  if (multi)
                    Row(
                      key: const ValueKey('home:dots'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pageCount; i++)
                          Semantics(
                            button: true,
                            selected: i == _page.clamp(0, pageCount - 1),
                            inMutuallyExclusiveGroup: true,
                            label: i == 0
                                ? 'Semua dompet, ${list.length} dompet'
                                : '${list[i - 1].name}, dompet ${i + 1} '
                                      'dari $pageCount',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // Tanpa haptic di sini: jumpToPage memicu
                              // onPageChanged → _pick yang sudah bergetar.
                              // Dulu ketukan dot bergetar dua kali.
                              onTap: () => _ctrl.jumpToPage(i),
                              child: SizedBox(
                                key: ValueKey('home:dots-$i'),
                                width: 28,
                                height: 32,
                                child: Center(
                                  child: _Dot(
                                    key: ValueKey('home:dots-$i-visual'),
                                    active: i == _page.clamp(0, pageCount - 1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('home:manage'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.touchMin),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                    ),
                    child: const Text('Kelola dompet'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Kartu gabungan "Semua dompet" (v1.38.0) — halaman 0 saat dompet >1.
///
/// Saldo = [balanceProvider] (semua dompet non-arsip, termasuk yang
/// diarsipkan riwayatnya). Kartu ini **tidak** punya tap: aksinya mengelola
/// dompet sudah ada di tombol `home:manage` di kanan, jadi tap di sini tidak
/// perlu menjanjikan halaman ketiga yang berbeda. Mata toggle tetap ada
/// karena ia satu-satunya cara menampilkan angka saat privacy aktif pada
/// halaman ini.
class _AllWalletsCard extends ConsumerWidget {
  const _AllWalletsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final total = ref.watch(balanceProvider);
    const white = Colors.white;

    return Container(
      key: const ValueKey('home:card-all'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: MeshGradient(
              padding: AppSpacing.cardPaddingLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sisakan 48px kanan untuk mata overlay.
                  Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: Text(
                      'Semua dompet',
                      style: AppType.labelMuted(context).copyWith(
                        letterSpacing: 0.8,
                        color: white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'SALDO GABUNGAN · $count DOMPET',
                    style: AppType.labelMuted(context).copyWith(
                      letterSpacing: 0.8,
                      color: white.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  total.when(
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
                          onPressed: () => ref.invalidate(balanceProvider),
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
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.s24,
            right: AppSpacing.s24,
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
    //
    // v1.32.3: mata toggle = SIBLING kartu (bukan anak) — Stack luar
    // selebar kartu penuh. Dulu mata Positioned di Stack DALAM yang
    // selebar kolom isi: saat saldo sempit (Rp0) kolom cuma 179px →
    // mata mendarat di tengah kartu menimpa 'SALDO SAAT INI' (probe:
    // eye 171-219 = label 40-219, OVERLAP true). Di sini Stack selebar
    // kartu penuh → right:24 selalu pojok kanan kartu. Bonus: tap mata
    // tak pernah masuk path hit-test Listener kartu → tak ada fire
    // ganda toggle+detail (probe R7: PREF true + DETAIL true).
    return Container(
      key: ValueKey('home:card-${account.id}'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Detail dompet ${account.name}',
              child: _TapToOpen(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AccountDetailScreen(accountId: account.id),
                    ),
                  );
                },
                child: MeshGradient(
                  padding: AppSpacing.cardPaddingLarge,
                  child: Column(
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
                              style: AppType.balance(context)
                                  .copyWith(fontSize: 20, color: white),
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
                            style: AppType.balanceHero(context)
                                .copyWith(color: white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // kartu fokus saldo; pintu catat = tombol + navbar, grid aksi,
                      // scan). Spacer s24 ikut dibuang agar kartu ramping.
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Mata toggle overlay pojok kanan-atas kartu (inset 24 = padding
          // isi, posisi visual sama seperti dulu saat kolom lebar).
          Positioned(
            top: AppSpacing.s24,
            right: AppSpacing.s24,
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

/// Tap-tanpa-arena untuk kartu di dalam PageView (v1.32).
///
/// [Listener] mentah tak mendaftarkan recognizer → gesture arena
/// PageView tak terganggu (drag bebas). Tap = down+up dalam slop 18px
/// tanpa gerakan berlebih; geser = pointer bergerak jauh → onTap tak
/// fire.
///
/// v1.32.3: mata toggle KELUAR dari subtree ini (sibling di Stack luar
/// kartu) — tap mata tak pernah masuk path hit-test Listener, jadi tak
/// ada fire ganda toggle+detail. Listener polos lagi (tanpa zona svc).
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

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      // v1.37.1: aktif = pill 18×6 (beda BENTUK + ukuran), non-aktif 6×6.
      // Sebelumnya cuma beda warna → melanggar WCAG 1.4.1 "jangan andalkan
      // warna saja", dan ukuran 6px terlalu kecil untuk dibaca sebagai
      // penanda posisi.
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        // Non-aktif pakai `outline`, bukan `outlineVariant`: sampel piksel
        // golden v1.31 menunjukkan outlineVariant hanya 1,63:1 (light) dan
        // 2,13:1 (dark) terhadap latar — di bawah 3:1 yang diminta WCAG
        // 1.4.11 untuk komponen UI. outline ada di ≈4-7:1.
        color: active ? scheme.primary : scheme.outline,
      ),
    );
  }
}
