import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_month_nav.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../components/mesh_gradient.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../greeting.dart';
import '../widgets/account_picker.dart';
import '../widgets/home_feature_grid.dart';
import '../widgets/tx_tile.dart';
import 'accounts_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'tx_form_screen.dart';

/// Redesign v1.24 B2C minimalis: header netral ramping, hero kartu putih
/// bersih (saldo 48px + 1 CTA), delta/kilat/debts dihapus, spacing 32px.
/// v1.26: menu fitur 4x2 (home:features) di bawah strip dompet;
/// Riwayat/Budget/Laporan/Utang dibuka via push dari grid (bukan tab).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onGoTab});

  /// Dipakai test sebagai pintu navigasi; shell v1.26 tak lagi pakai
  /// (grid push langsung). Dipertahankan agar 17 call-site test tak pecah.
  final ValueChanged<int>? onGoTab;

  // SECTION: HomeScreen.build dengan header minimalis + slot redesign
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final balance = ref.watch(balanceProvider);
    final dayTotals = ref.watch(dayTotalsProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);
    final showTop = ref.watch(showTopCategoriesProvider).value ?? true;
    final showRecent = ref.watch(showRecentProvider).value ?? true;
    final recentCount = ref.watch(recentCountProvider).value ?? 5;
    final showDaily = ref.watch(showDailyTotalsProvider).value ?? true;
    final statusPad = MediaQuery.paddingOf(context).top;
    // Status bar adaptif (kritik brutal v1.24.2): ikon terang di dark,
    // gelap di light — bukan hardcode gelap terus.
    final isDark = AppColors.isDark(context);

    void shift(int d) =>
        ref.read(selectedMonthProvider.notifier).state = shiftMonth(month, d);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header v1.27: belum login = wordmark MyWallet (tak berubah);
            // sudah login = avatar + sapaan → Profil. Kanan = gear saja.
            Padding(
              key: const ValueKey('home:header'),
              padding: EdgeInsets.only(
                left: AppSpacing.page,
                top: statusPad + AppSpacing.s8,
                bottom: AppSpacing.s8,
                right: AppSpacing.page,
              ),
              child: _HomeHeader(
                onSettings: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                onProfile: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Hero minimalis (redesign v1.24): kartu putih bersih,
                  // saldo 48px + 1 CTA solid — elemen dominan pertama.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:hero-slot'),
                    child: _HeroCard(balance: balance),
                  ),
                  // v1.25: pemilih dompet (Semua + chip + Kelola).
                  // 1 baris ramping.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:accounts'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s12),
                      child: AccountPicker(
                        onManage: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AccountsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // v1.26: menu fitur 4x2 (aksi + lihat) di bawah dompet,
                  // di atas nav bulan — Beranda jadi pintu masuk semua.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:features'),
                    child: _pad(
                      const HomeFeatureGrid(),
                      top: AppSpacing.sectionGapLarge,
                    ),
                  ),
                  // Nav bulan: chip bulan jadi penanda konteks + kontrol
                  // bulan aktif (shared selectedMonthProvider).
                  SliverToBoxAdapter(
                    key: const ValueKey('home:monthnav'),
                    child: _pad(
                      AppMonthNav(month: month, onShift: shift),
                      top: AppSpacing.sectionGapLarge,
                    ),
                  ),
                  // Redesign v1.24 B2C minimalis: delta/kilat/debts DIHAPUS
                  // (cognitive load). Spacing lega via token sectionGapLarge.
                  // Top kategori + terakhir dicatat tampil langsung.
                  if (showTop) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGapLarge),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:topcats'),
                      child: _pad(
                        AppSection(
                          title: 'Pengeluaran bulan ini',
                          trailing: TextButton(
                            // v1.24.3: label konteks, bukan generik
                            // "Lihat semua" (kritik brutal L5).
                            // v1.26: push langsung (tab 3 sudah tak ada).
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReportsScreen(),
                              ),
                            ),
                            child: const Text('Semua kategori'),
                          ),
                          child: _CategoryList(byCat: byCat, display: display),
                        ),
                      ),
                    ),
                  ],
                  if (showRecent) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGapLarge),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:recent'),
                      child: _pad(
                        AppSection(
                          title: 'Terakhir dicatat',
                          trailing: TextButton(
                            // v1.24.3: label konteks (kritik brutal L5).
                            // v1.26: push langsung (tab 1 sudah tak ada).
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HistoryScreen(),
                              ),
                            ),
                            child: const Text('Semua transaksi'),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDaily) _DailyStrip(dayTotals: dayTotals),
                              _RecentList(count: recentCount),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.bottomPad),
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

/// Padding horizontal halaman untuk satu section.
/// Redesign v1.24: stagger entrance dihapus (instant load).
Widget _pad(Widget child, {double top = 0}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.page, top, AppSpacing.page, 0),
    child: child,
  );
}

/// Hero mesh cair (identitas v1.28): MeshGradient ikut aksen + teks
/// putih + CTA putih solid. CUMA saldo sebagai fokus tunggal + 1 CTA.
/// Masuk/Keluar + budget ledger + tombol ganda DIHAPUS (tetap).
///
/// Kontrak test: key 'home:hero', 'SALDO SAAT INI' (1x), mata toggle,
/// '+ Catat keluar' (1x). Kontras putih ≥4.5:1 di 6 aksen × 2 tema
/// dikunci visual_identity_test (bukan eyeball).
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.balance});
  final AsyncValue<int> balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    const white = Colors.white;

    return MeshGradient(
      key: const ValueKey('home:hero'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s24,
        AppSpacing.page,
        0,
      ),
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + mata toggle (putih di atas mesh).
          Row(
            children: [
              Expanded(
                child: Text(
                  'SALDO SAAT INI',
                  style: AppType.labelMuted(context).copyWith(
                    letterSpacing: 0.8,
                    color: white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // v1.24.8: mata via AppIconButton polos (satu komponen,
              // 48px token + haptic, bukan manual 44px).
              AppIconButton(
                icon: hide
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                color: white.withValues(alpha: 0.92),
                bordered: false,
                onPressed: () =>
                    ref.read(settingsServiceProvider).setHideBalance(!hide),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          // Saldo RAKSASA dominan (48px, lebih besar dari v1.23 40px)
          balance.when(
            loading: () => const AppSkeleton(lines: 1),
            error: (e, _) => Column(
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
              // v1.24.2: scaleDown agar nominal miliaran mengecil,
              // bukan kepotong '...' (kritik brutal).
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
          // CTA tunggal: Catat pengeluaran — kapsul PUTIH solid di atas
          // mesh (identitas v1.28). Teks = primary gelap via colorScheme
          // (bukan putih hardcode — kontras dikunci test semua aksen).
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
    );
  }
}

/// Top kategori PROPORSIONAL terhadap total (bukan terhadap maksimum):
/// bar terpanjang = porsi terbesar, plus persen per baris.
/// Perhitungan & query tidak berubah — hanya presentasi.
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.byCat, required this.display});
  final AsyncValue<List<CategoryTotal>> byCat;
  final DisplayPrefs display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return byCat.when(
      loading: () => const AppSkeleton(lines: 3),
      error: (e, _) => AppErrorState(
        title: 'Kategori gagal dimuat.',
        onRetry: () => ref.invalidate(monthExpenseByCategoryProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: '📊',
            title: 'Belum ada pengeluaran bulan ini',
            subtitle: 'Catat pengeluaran pertamamu bulan ini.',
          );
        }
        final total = list.fold<int>(0, (s, e) => s + e.total);
        return Column(
          children: [
            for (final c in list.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Row(
                  children: [
                    CategoryGlyph(emoji: c.icon, size: 36, iconSize: 18),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                total == 0
                                    ? '0%'
                                    : '${(100 * c.total / total).round()}%',
                                style: AppType.secondaryStrong(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          AppProgress(
                            value: total == 0
                                ? 0
                                : (c.total / total).clamp(0.0, 1.0),
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(
                      display.money(c.total),
                      // v1.24.3: 14→15 samakan nominal transaksi (kritik L3).
                      style: AppType.amount(context),
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

/// Ringkasan masuk/keluar HARI INI — pindahan dari tile metrik ketiga
/// (mockup: baris metrik khusus Masuk/Keluar/Sisa budget). Ikut toggle
/// "Ringkasan hari ini" di Pengaturan → Tampilan.
class _DailyStrip extends ConsumerWidget {
  const _DailyStrip({required this.dayTotals});
  final AsyncValue<(int, int)> dayTotals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    return dayTotals.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        if (d.$1 == 0 && d.$2 == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          // v1.24.5: SATU baris ringkasan (audit arsitektur: "Hari ini"
          // dobel — strip + header grup pertama bertumpuk). Label depan
          // dihapus, tanggal ikut header grup di bawahnya.
          child: Text(
            'Masuk ${display.signed(d.$1, isExpense: false)} · '
            'Keluar ${display.signed(d.$2, isExpense: true)}',
            style: AppType.secondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

/// Header Beranda v1.27: identitas kondisional login.
///
/// Belum login (`personal`/loading) = wordmark `MyWallet` + tombol teks
/// `Masuk` → Profil + gear. Sudah login = avatar inisial 40px + sapaan
/// 2 baris (kecil sapaan waktu + tebal nama) dalam satu InkWell → Profil.
/// Kanan selalu gear → Pengaturan.
///
/// v1.27.1: tombol `Masuk` menutup lubang discoverability — Profil/Family
/// hanya reachable dari identitas login, jadi logged-out terkunci total
/// tanpa tombol ini. TextButton ringan (bukan FilledButton) agar tak
/// berteriak saingan CTA hero; tampil saat loading juga (tap → Profil
/// personal, tombol Google besar tetap bisa ditekan manual — fallback
/// v1.17.3), jadi tak ada kedip muncul-hilang.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.onSettings, required this.onProfile});

  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(familySessionProvider);
    final nickname = ref.watch(displayNameProvider);
    final scheme = Theme.of(context).colorScheme;

    final gear = AppIconButton(
      icon: Icons.settings_outlined,
      onPressed: onSettings,
      tooltip: 'Pengaturan',
      bordered: false,
    );

    // Riverpod 3.4.3: AsyncValue pakai `.value` (bukan valueOrNull).
    final s = session.value;
    final loggedIn = s != null && !s.isPersonal;
    if (!loggedIn) {
      // Personal/loading: wordmark + tombol Masuk → Profil + gear.
      return Row(
        children: [
          Expanded(
            child: Text(
              'MyWallet',
              style: AppType.screenTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onProfile();
            },
            child: const Text('Masuk'),
          ),
          gear,
        ],
      );
    }

    final name = resolveGreetingName(
      manualName: nickname.value,
      googleName: s.displayName,
    );
    final initial = ((name ?? 'M').characters.first).toUpperCase();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onProfile();
            },
            borderRadius: AppRadius.mdAll,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greetingTitle(DateTime.now()),
                        style: AppType.secondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        name ?? 'Akun saya',
                        style: AppType.screenTitle(
                          context,
                        ).copyWith(fontSize: 20),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        gear,
      ],
    );
  }
}

/// Transaksi terakhir dikelompokkan per tanggal (header tanggal +
/// baris ber-chevron). Seluruh baris tap → edit, affordance kelihatan.
class _RecentList extends ConsumerWidget {
  const _RecentList({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final display = ref.watch(displayPrefsProvider);
    return StreamBuilder<List<TxWithCategory>>(
      stream: db.watchHistory(limit: count),
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
            subtitle:
                // v1.24.3: jujur — CTA Beranda buka form pengeluaran
                // (kritik brutal L4: janji "pemasukan" meleset).
                'Ketuk + Catat keluar untuk mencatat pengeluaran.',
          );
        }
        final groups = <DateTime, List<TxWithCategory>>{};
        for (final tx in list) {
          final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
          (groups[d] ??= []).add(tx);
        }
        final entries = groups.entries.toList()
          // v1.24.5: sort eksplisit DESC — urutan grup JANGAN kebetulan
          // ikut ORDER BY query (audit arsitektur: bom waktu kecil).
          ..sort((a, b) => b.key.compareTo(a.key));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : AppSpacing.s12,
                  bottom: AppSpacing.s4,
                ),
                child: Text(
                  display.date(entries[i].key),
                  // v1.24.4: header grup naik ke sectionTitle — tanggal
                  // grup adalah judul, bukan teks sekunder.
                  style: AppType.sectionTitle(context).copyWith(fontSize: 14),
                ),
              ),
              for (final tx in entries[i].value)
                TxTile(
                  tx: tx,
                  // v1.24.4: tanggal sudah di header grup → sembunyikan
                  // di tiap baris (rapikan "Ke..." kepotong).
                  showDate: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TxFormScreen(existing: tx),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
