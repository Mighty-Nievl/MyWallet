import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_card.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../components/period_switcher.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../greeting.dart';
import '../scan_flow.dart';
import '../transaction_actions.dart';
import '../widgets/account_carousel.dart';
import '../widgets/flow_cards.dart';
import '../widgets/home_feature_grid.dart';
import '../widgets/tx_tile.dart';
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
    // v1.36.0: Beranda tidak lagi dipaku ke bulan — semua angka utama
    // ikut periode aktif (switcher harian/mingguan/bulanan/tahunan).
    final period = ref.watch(activePeriodProvider);
    // v1.29: balanceProvider menganggur di Beranda (carousel pakai
    // accountBalanceProvider per-dompet). Provider dipertahankan —
    // dipakai debug + kontrak angka gabungan tetap ada.
    final dayTotals = ref.watch(dayTotalsProvider);
    final byCat = ref.watch(periodExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);
    final showTop = ref.watch(showTopCategoriesProvider).value ?? true;
    final showRecent = ref.watch(showRecentProvider).value ?? true;
    final recentCount = ref.watch(recentCountProvider).value ?? 5;
    final showDaily = ref.watch(showDailyTotalsProvider).value ?? true;
    // v1.38.0: nol transaksi = user baru. null (loading) dianggap
    // "sudah ada data" supaya onboarding tidak berkedip.
    final newUser = ref.watch(hasAnyTxProvider).value == false;
    // v1.30: suffix dompet utk judul section (jujur: angka milik siapa).
    final acctSuffix = accountTitleSuffix(
      ref.watch(accountsProvider).value ?? const <Account>[],
      ref.watch(selectedAccountProvider),
    );
    final statusPad = MediaQuery.paddingOf(context).top;
    // Status bar adaptif (kritik brutal v1.24.2): ikon terang di dark,
    // gelap di light — bukan hardcode gelap terus.
    final isDark = AppColors.isDark(context);

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
                  // v1.29: carousel kartu per-dompet gantikan hero
                  // gabungan + strip chip (satu kontrol: kartu tampil
                  // = filter aktif).
                  SliverToBoxAdapter(
                    key: const ValueKey('home:hero-slot'),
                    child: const AccountCarousel(),
                  ),
                  // v1.38.0: user benar-benar baru (nol transaksi) dapat satu
                  // jalan masuk, bukan saldo Rp0 + dua kartu Rp0 + dua empty
                  // state bertumpuk. yang butuh data bisa langsung mulai.
                  if (newUser)
                    SliverToBoxAdapter(
                      key: const ValueKey('home:onboarding'),
                      child: _pad(
                        const _OnboardingStart(),
                        top: AppSpacing.s16,
                      ),
                    )
                  else ...[
                    // v1.37: periode naik ke atas angka yang dipengaruhinya.
                    // Dulu FlowCards tampil sebelum switcher → user melihat
                    // total periode tanpa tahu rentangnya. Key lama
                    // (`home:monthnav`) dipertahankan agar test/lokasi
                    // kontrol tidak pecah.
                    SliverToBoxAdapter(
                      key: const ValueKey('home:monthnav'),
                      child: _pad(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PeriodSwitcher(),
                            const SizedBox(height: AppSpacing.s8),
                            PeriodNav(period: period),
                          ],
                        ),
                        top: AppSpacing.s16,
                      ),
                    ),
                  // v1.34.0: arus kas periode aktif — Pemasukan &
                  // Pengeluaran sebagai kartu sendiri. Dulu angka ini
                  // hanya ada di Laporan; di Beranda user cuma lihat
                  // saldo, jadi tak tahu uang masuk/keluar bulan ini.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:flowcards'),
                    child: _pad(const FlowCards(), top: AppSpacing.s12),
                  ),
                  // v1.37: transaksi terakhir naik ke atas kategori/menu.
                  // Ini data yang paling sering dicari saat membuka app;
                  // jangan biarkan terkubur di bawah 8 tombol menu.
                  if (showRecent) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGapLarge),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:recent'),
                      child: _pad(
                        AppSection(
                          title: 'Terakhir dicatat$acctSuffix',
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
                  // Redesign v1.24 B2C minimalis: delta/kilat/debts DIHAPUS
                  // (cognitive load). Spacing lega via token sectionGapLarge.
                  // v1.37: kategori turun setelah transaksi terakhir.
                  if (showTop) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGapLarge),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:topcats'),
                      child: _pad(
                        AppSection(
                          title:
                              'Pengeluaran ${periodRelativeLabel(period)}$acctSuffix',
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
                  ],
                  // v1.37: menu ringkas (4 pintasan unik) turun ke bawah
                  // data. Catat/Scan/Riwayat sudah ada di dock, jadi
                  // tidak diduplikasi lagi di sini.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:features'),
                    child: _pad(
                      const HomeFeatureGrid(),
                      top: AppSpacing.sectionGapLarge,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      // v1.32.6: clearance adaptif = bottomPad + safeBottom
                      // aktual. Rumus v1.36.0: dockSlot 76 + safe + breath
                      // 44. Emulator safe=0 → 120; HP gesture-nav ≈16-24 →
                      // 136-144. Beranda satu-satunya body shell → cuma
                      // ekor ini yang adaptif (9 layar lain Scaffold
                      // sendiri, kapsul FAB tak tampil saat push).
                      // v1.33.0: kapsul = FAB overlay → body penuh, jadi
                      // ekor inilah satu-satunya penjaga kartu terakhir.
                      height:
                          AppSpacing.bottomPad +
                          MediaQuery.paddingOf(context).bottom,
                    ),
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

/// Suffix judul jujur dompet (v1.30 — label dompet di Beranda):
/// null (Semua) = tanpa suffix; spesifik = ` · Nama`.
/// 1 dompet = tanpa suffix (semua angka pasti miliknya — cermin aturan
/// meta tile `showAccount: multiWallet`). Suffix hanya bermakna bila
/// >1 dompet, saat ambiguitasnya nyata.
/// Dipanggil dgn daftar dompet + id terpilih (murni, testable).
String accountTitleSuffix(List<Account> accounts, int? selectedId) {
  if (selectedId == null || accounts.length <= 1) return '';
  for (final a in accounts) {
    if (a.id == selectedId) return ' · ${a.name}';
  }
  return '';
}

/// Padding horizontal halaman untuk satu section.
/// Redesign v1.24: stagger entrance dihapus (instant load).
Widget _pad(Widget child, {double top = 0}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.page, top, AppSpacing.page, 0),
    child: child,
  );
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
    final period = ref.watch(activePeriodProvider);
    final relative = periodRelativeLabel(period);
    return byCat.when(
      loading: () => const AppSkeleton(lines: 3),
      error: (e, _) => AppErrorState(
        title: 'Kategori gagal dimuat.',
        onRetry: () => ref.invalidate(periodExpenseByCategoryProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: '📊',
            title: 'Belum ada pengeluaran $relative',
            subtitle: 'Catat pengeluaran pertamamu $relative.',
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
          // v1.37: label eksplisit. Strip ini hidup di bawah ringkasan
          // periode; tanpa "Hari ini" angkanya mudah disangka total
          // periode yang sama.
          child: Text(
            'Hari ini · Masuk ${display.signed(d.$1, isExpense: false)} · '
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
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
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
                        style: AppType.screenTitle(context)
                            .copyWith(fontSize: 20),
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
/// v1.30: ikut filter dompet aktif ([selectedAccountProvider] — konsisten
/// dgn kartu tampil = filter aktif) + label dompet per-baris bila >1.
class _RecentList extends ConsumerWidget {
  const _RecentList({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final display = ref.watch(displayPrefsProvider);
    // Label dompet hanya bermakna bila >1 dompet (1 dompet = semua baris
    // miliknya, suffix cuma noise).
    final multiWallet = (ref.watch(accountsProvider).value?.length ?? 0) > 1;
    return StreamBuilder<List<TxWithCategory>>(
      stream: db.watchHistory(
        limit: count,
        accountId: ref.watch(selectedAccountProvider),
      ),
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
                // v1.37: grid "Catat keluar" sudah tidak ada; satu-satunya
                // pintu = + di dock (form pilih tipe sendiri). Jangan
                // menyebut tombol yang tak lagi tampil.
                'Ketuk + di bilah bawah untuk mencatat transaksi pertamamu.',
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
              for (final tx in entries[i].value) ...[
                // Rapat kartu (v1.30.1): tiap baris = kartu => butuh napas
                // s8 antar kartu (atas kartu kecuali yg pertama di grup).
                Padding(
                  padding: EdgeInsets.only(
                    top: tx == entries[i].value.first ? 0 : AppSpacing.s8,
                  ),
                  child: TxTile(
                    tx: tx,
                    // v1.24.4: tanggal sudah di header grup → sembunyikan
                    // di tiap baris (rapikan "Ke..." kepotong).
                    showDate: false,
                    // v1.30: label dompet (Riwayat & Terakhir catat wajib
                    // sebut dompet asal bila >1).
                    showAccount: multiWallet,
                    onTap: () => openTransaction(context, ref, tx),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Onboarding Beranda (v1.38.0): pengganti tumpukan empty state untuk user
/// yang belum punya satu transaksi pun.
///
/// Satu tujuan utama (catat pengeluaran) + satu alternatif (scan struk).
/// Analitik periode sengaja tidak ditampilkan: switcher Harian/Mingguan/
/// Bulanan/Tahunan tanpa data hanya menawarkan pilihan kosong.
class _OnboardingStart extends ConsumerWidget {
  const _OnboardingStart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mulai dari satu catatan', style: AppType.sectionTitle(context)),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Belum ada transaksi. Catat pengeluaran pertamamu — 10 detik, '
            'tanpa akun, semua tersimpan di HP ini.',
            style: AppType.secondary(context),
          ),
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('home:onboarding-cta'),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TxFormScreen(startAsExpense: true),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Catat pengeluaran pertama'),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('home:onboarding-scan'),
              onPressed: () {
                HapticFeedback.selectionClick();
                runScanFlow(context, ref);
              },
              icon: Icon(
                Icons.document_scanner_outlined,
                size: 18,
                color: scheme.primary,
              ),
              label: const Text('Atau scan struk belanja'),
            ),
          ),
        ],
      ),
    );
  }
}
