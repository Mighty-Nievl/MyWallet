import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../components/app_empty_state.dart';
import '../components/app_feedback.dart';
import '../components/app_month_nav.dart';
import '../components/app_progress.dart';
import '../components/app_section.dart';
import '../components/category_glyph.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../widgets/tx_tile.dart';
import 'categories_screen.dart';
import 'settings_screen.dart';
import 'tx_form_screen.dart';

/// Ambang waspada budget (sama dengan layar Budget).
const _warnAt = 0.8;

/// Warna bar budget saat waspada (sama dengan layar Budget).
const _warnAmber = Color(0xFFFBBF24);

/// Latar banner insight gelap (satu-satunya warna netral hard-code di
/// halaman ini — dipakai sebagai LATAR kartu, bukan teks).
const _darkBanner = Color(0xFF171717);

/// Gradien aksen untuk kartu saldo — IKUT warna aksen tema
/// (Pengaturan → Tampilan): default hijau, bisa biru ala GoPay,
/// ungu, oranye, dll tanpa kode terpisah.
///
/// Dipakai hero kartu + kotak banner: dasar dijenuhkan dulu, lalu
/// digelapkan HANYA sampai teks putih lolos kontras ≥4.5:1.
double _whiteContrast(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  final l = 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  return 1.05 / (l + 0.05);
}

Color _accentStop(BuildContext context, double amount) {
  var c = Color.lerp(
    Theme.of(context).colorScheme.primary,
    Colors.black,
    amount,
  )!;
  var guard = 0;
  while (_whiteContrast(c) < 5.0 && guard++ < 24) {
    c = Color.lerp(c, Colors.black, 0.10)!;
  }
  return c;
}

/// Tiga stop DITURUNKAN dari satu base yang sudah lolos kontras
/// (stop turunan selalu lebih gelap → kontras membaik), supaya
/// gradien tetap terbaca di mode gelap — versi loop per-stop bikin
/// semua stop mentok di lantai kontras yang sama (kartu jadi rata).
LinearGradient _accentGradient(BuildContext context) {
  final base = _heroBase(context);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      base,
      Color.lerp(base, Colors.black, 0.12)!,
      Color.lerp(base, Colors.black, 0.25)!,
    ],
  );
}

/// Dasar kartu saldo: aksen tema DJENUHKAN (+35%) lalu kontras putih
/// disetel ke lantai 4.7:1.
///
/// Kenapa: `colorScheme.primary` hasil tonal Material 3 kurang jenuh
/// (#1C684E) sedangkan mockup ala GoPay memakai warna seed murni
/// (#0E795A ≈ seed hijau kita) — bedanya bikin kartu terasa kusam.
/// Boost jenuh + lantai kontras = warna seliar mockup DAN teks putih
/// tetap WCAG AA (diuji 6 aksen × 2 tema di home_design_test).
Color _heroBase(BuildContext context) {
  final hsl = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
  var c = hsl.withSaturation((hsl.saturation * 1.35).clamp(0.0, 1.0)).toColor();
  var guard = 0;
  while (_whiteContrast(c) < 4.7 && guard++ < 24) {
    final h = HSLColor.fromColor(c);
    c = h.withLightness((h.lightness - 0.03).clamp(0.0, 1.0)).toColor();
  }
  return c;
}

/// Latar band kepala — lebih gelap dari kartu supaya kartu saldo
/// terlihat "numpuk" di atasnya (efek dimensi khas GoPay).
Color _topColor(BuildContext context) => _accentStop(context, 0.70);

/// Total pengeluaran BULAN SEBELUMNYA (delta % di banner insight).
/// Provider, bukan FutureBuilder di dalam build — query jalan sekali
/// per bulan terpilih, tidak diulang tiap rebuild.
final _prevMonthExpenseProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(dbProvider);
  final (from, to) = monthRangeOf(
    shiftMonth(ref.watch(selectedMonthProvider), -1),
  );
  return (await db.getTotals(from, to)).$2;
});

/// Beranda (pola GoPay): kepala sapaan berwarna aksen, kartu saldo
/// gradien aksen, deretan aksi cepat, banner insight, tile metrik,
/// top kategori proporsional, terakhir dikelompokkan per tanggal.
///
/// Header PINNED (di luar scroll) — pintu Pengaturan tidak pernah
/// hilang. Scroll: CustomScrollView dengan TEPAT SATU
/// SliverToBoxAdapter per section (berkunci ValueKey).
///
/// Warna kartu/kepala NGIKUT aksen tema → pengguna memilih gaya
/// (hijau default, biru ala GoPay) lewat Pengaturan → Tampilan.
///
/// Logika bisnis TETAP: provider, perhitungan, query, navigasi bulan,
/// navigasi ke Pengaturan & form tidak disentuh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onGoTab});

  /// Lompat tab shell (0=Beranda, 1=Riwayat, 2=Budget, 3=Laporan).
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final balance = ref.watch(balanceProvider);
    final totals = ref.watch(monthTotalsProvider);
    final dayTotals = ref.watch(dayTotalsProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final display = ref.watch(displayPrefsProvider);
    final showTop = ref.watch(showTopCategoriesProvider).value ?? true;
    final showRecent = ref.watch(showRecentProvider).value ?? true;
    final recentCount = ref.watch(recentCountProvider).value ?? 5;

    final name = ref.watch(displayNameProvider).value ?? 'Nievi';
    final showDaily = ref.watch(showDailyTotalsProvider).value ?? true;
    final now = DateTime.now();
    // Tinggi bar status perangkat (0 di golden/mockup) — konten kepala
    // didorong ke bawah supaya tidak tertimpa jam/baterai.
    final statusPad = MediaQuery.paddingOf(context).top;

    void shift(int d) =>
        ref.read(selectedMonthProvider.notifier).state = shiftMonth(month, d);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Kepala GELAP dari tepi atas → ikon status selalu TERANG
      // (kedua mode; halaman di bawahnya tidak mempengaruhi bar atas).
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          // Stretch → Stack kepala selebar layar (SizedBox penanda
          // tinggi hero tidak punya lebar bawaan).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kepala mockup (referensi 8 Okt): blok gelap menepi dari
            // tepi atas (radius atas = kelengkungan layar), kartu saldo
            // MENUMPUK separuh masuk ke blok & separuh keluar ke halaman
            // terang. Ruang 390: blok y0-126, kartu y73-219 — kartu
            // ber-padding horizontal 16px di dalam blok gelap.
            Stack(
              children: [
                SizedBox(height: statusPad + 219),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xxl),
                    ),
                    child: Container(
                      key: const ValueKey('home:header'),
                      color: _topColor(context),
                      padding: EdgeInsets.only(
                        top: statusPad + 18,
                        bottom: 60,
                        left: AppSpacing.page,
                        right: 8,
                      ),
                      child: Row(
                        children: [
                          // Avatar inisial ala mockup — lingkaran hijau
                          // solid di kiri sapaan; ketuk = Pengaturan.
                          // Tombol dipaksa 48px oleh framework (min
                          // sentuh) → bungkus SizedBox lebar 40 supaya
                          // lingkaran mulai di x16 dan nama di x68.
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 48,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              tooltip: 'Profil',
                              icon: CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  _avatarInitial(name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _greeting(name),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.screenTitle(context)
                                            .copyWith(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                      ),
                                    ),
                                    if (name.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      // Mahkota kecil ala mockup.
                                      const Text(
                                        '👑',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_weekday(now.weekday)}, '
                                  '${formatDateLong(now)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.secondary(context).copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Lonceng + gear rapat ala mockup (pusat ikon
                          // 40px) — dibungkus SizedBox karena IconButton
                          // selalu melebar ke 48px.
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 48,
                              ),
                              onPressed: () => ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Belum ada notifikasi.'),
                                  ),
                                ),
                              tooltip: 'Notifikasi',
                              icon: const Icon(
                                Icons.notifications_none_outlined,
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                iconSize: 24,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          // Gear: pusat 40px dari lonceng, ala mockup.
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 48,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              tooltip: 'Pengaturan',
                              icon: const Icon(Icons.settings_outlined),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                iconSize: 24,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.mdAll,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: statusPad + 73,
                  left: AppSpacing.page,
                  right: AppSpacing.page,
                  child: _HeroCard(balance: balance, onGoTab: onGoTab),
                ),
              ],
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Nav bulan hanya tampil saat menjelajah bulan LAIN —
                  // tampilan default mengikuti mockup: sapaan → kartu →
                  // aksi cepat. Saat aktif, chip "Bulan ini" di dalamnya
                  // menjadi jalan pulang ke bulan berjalan.
                  if (month != currentMonthKey())
                    SliverToBoxAdapter(
                      key: const ValueKey('home:monthnav'),
                      child: _pad(
                        AppMonthNav(month: month, onShift: shift),
                        top: AppSpacing.s16,
                      ),
                    ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:quickactions'),
                    child: _pad(_QuickActions(onGoTab: onGoTab)),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:banners'),
                    child: _pad(
                      _InsightBanners(
                        month: month,
                        totals: totals,
                        onGoTab: onGoTab,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:quickcats'),
                    child: _pad(_QuickCategories(onGoTab: onGoTab)),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:tiles'),
                    child: _pad(_StatTiles(month: month, totals: totals)),
                  ),
                  if (showTop) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGap),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:topcats'),
                      child: _pad(
                        AppSection(
                          title: 'Pengeluaran bulan ini',
                          trailing: onGoTab == null
                              ? null
                              : TextButton(
                                  onPressed: () => onGoTab!(3),
                                  child: const Text('Lihat semua'),
                                ),
                          child: _CategoryList(byCat: byCat, display: display),
                        ),
                      ),
                    ),
                  ],
                  if (showRecent) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sectionGap),
                    ),
                    SliverToBoxAdapter(
                      key: const ValueKey('home:recent'),
                      child: _pad(
                        AppSection(
                          title: 'Terakhir dicatat',
                          trailing: onGoTab == null
                              ? null
                              : TextButton(
                                  onPressed: () => onGoTab!(1),
                                  child: const Text('Lihat semua'),
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
Widget _pad(Widget child, {double top = 0}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.page, top, AppSpacing.page, 0),
    child: child,
  );
}

/// Sapaan personal ala mockup ("Hai, Nievi" + mahkota) — nama di
/// Pengaturan → Tampilan → Nama sapaan. Kosong = sapaan polos "Hai!".
String _greeting(String name) => name.isEmpty ? 'Hai!' : 'Hai, $name';

/// Inisial avatar header (mockup: lingkaran inisial di kiri sapaan).
/// Nama kosong → 'M' (MyWallet).
String _avatarInitial(String name) {
  final t = name.trim();
  return t.isEmpty ? 'M' : t[0].toUpperCase();
}

/// Sisa hari dalam bulan [key] — sub-label tile "SISA BUDGET".
int _daysLeftInMonth(String key) {
  final parts = key.split('-');
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = int.tryParse(parts[1]) ?? DateTime.now().month;
  if (m < 1 || m > 12) return 0;
  final last = DateTime(y, m + 1, 0).day;
  final nowKey = currentMonthKey();
  if (key == nowKey) return last - DateTime.now().day + 1;
  if (key.compareTo(nowKey) > 0) return last;
  return 0;
}

String _weekday(int w) {
  const names = [
    '',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  return (w >= 1 && w <= 7) ? names[w] : '';
}

/// Kartu saldo (pola GoPay): gradien aksen + saldo SEMUA WAKTU +
/// tombol aksi. Arus bulan, delta, dan budget pindah ke tile & banner
/// di bawah — kartu ringkas, hanya berisi hal yang selalu berlaku.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.balance, required this.onGoTab});

  final AsyncValue<int> balance;
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('home:hero'),
      // Padat ala mockup referensi: padding 16px di semua sisi —
      // label/angka/pil sejajar rapi, kartu punya napas horizontal.
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: _accentGradient(context),
        // Menumpuk di blok kepala: radius 16 sama di empat sudut
        // (mockup) — separuh kartu di blok gelap, separuh di halaman.
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Stack: ikon mata di luar alur teks supaya baris label setinggi
      // teksnya sendiri (padat ala mockup) — target sentuh 48px utuh.
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SALDO MYWALLET',
                style: AppType.labelMuted(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              balance.when(
                loading: () => Text(
                  '…',
                  style: AppType.balance(context).copyWith(color: Colors.white),
                ),
                error: (e, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo gagal dimuat.',
                      style: AppType.balance(
                        context,
                      ).copyWith(color: Colors.white, fontSize: 20),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(balanceProvider),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
                data: (b) => Text(
                  hide ? 'Rp••••••' : display.money(b),
                  style: AppType.balance(context).copyWith(
                    color: Colors.white,
                    // 29px: lebar angka menyamai mockup (32 terlalu lebar).
                    fontSize: 29,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      context,
                      label: '+ Catat',
                      solid: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TxFormScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _pillButton(
                      context,
                      label: '- Pengeluaran',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const TxFormScreen(startAsExpense: true),
                        ),
                      ),
                    ),
                  ),
                  if (onGoTab != null) ...[
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(
                      child: _pillButton(
                        context,
                        label: 'Detail',
                        onTap: () => onGoTab!(3),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // Mata toggle saldo — mockup: ikon terlipat saat saldo tampil,
          // di baris label tepi kanan (right -16 dari tepi kartu).
          Positioned(
            top: 0,
            right: -14,
            child: IconButton(
              alignment: Alignment.centerRight,
              onPressed: () =>
                  ref.read(settingsServiceProvider).setHideBalance(!hide),
              icon: Icon(
                hide
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 16,
              ),
              tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
              color: Colors.white,
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(
                  AppSpacing.touchMin,
                  AppSpacing.touchMin,
                ),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol pil ala mockup: solid putih (teks aksen gelap) atau ghost
/// putih 15% di atas gradien. Bila aksen tema terang sehingga teks
/// putih di ghost <4.5:1, fallback hitam 30% (menggelapkan) — kontras
/// terjaga di semua aksen. Tinggi 40px (mockup 39px).
Widget _pillButton(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
  bool solid = false,
}) {
  // Perkiraan latar ghost: putih 15% di atas tengah gradien.
  final ghostOver = Color.lerp(_accentStop(context, 0.5), Colors.white, 0.15)!;
  final whiteOk = _whiteContrast(ghostOver) >= 4.5;
  final ghost = whiteOk
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.30);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(999),
    side: BorderSide(
      color: Colors.white.withValues(alpha: solid || whiteOk ? 0 : 0.40),
    ),
  );
  return Material(
    color: solid ? Colors.white : ghost,
    shape: shape,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 40,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.secondary(context).copyWith(
              // Teks gelap hasil aksen pekat: lolos kontras di atas
              // putih, termasuk saat aksen mode gelap (tone terang).
              color: solid ? _accentStop(context, 0.45) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Deretan 5 aksi cepat (pola lingkaran GoPay): Budget, Laporan,
/// Riwayat, Kategori, Bulan ini — persis urutan mockup. Target 48px.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.onGoTab});
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      if (onGoTab != null) ...[
        (
          icon: Icons.savings_outlined,
          label: 'Budget',
          onTap: () => onGoTab!(2),
        ),
        (
          icon: Icons.bar_chart_outlined,
          label: 'Laporan',
          onTap: () => onGoTab!(3),
        ),
        (
          icon: Icons.receipt_long_outlined,
          label: 'Riwayat',
          onTap: () => onGoTab!(1),
        ),
      ],
      (
        icon: Icons.sell_outlined,
        label: 'Kategori',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: _quickItem(
                context,
                icon: it.icon,
                label: it.label,
                onTap: it.onTap,
              ),
            ),
        ],
      ),
    );
  }
}

Widget _quickItem(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: AppRadius.mdAll,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Column(
        children: [
          Container(
            width: AppSpacing.touchMin,
            height: AppSpacing.touchMin,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppType.secondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

/// Pintasan kategori (pola grid layanan GoPay): ketuk → tab Riwayat
/// dengan filter kategori itu; "Semua" mengosongkan filter. Glyph
/// monochrome (CategoryGlyph) menjaga bahasa desain aplikasi.
class _QuickCategories extends ConsumerWidget {
  const _QuickCategories({required this.onGoTab});
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goTab = onGoTab;
    if (goTab == null) return const SizedBox.shrink();
    final cats = ref.watch(categoriesProvider);
    return cats.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final tint = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kategori cepat',
                      style: AppType.sectionTitle(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(historyFilterProvider.notifier).state =
                          const HistoryFilter();
                      goTab(1);
                    },
                    child: const Text('Semua'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  for (final c in list.take(5))
                    Expanded(
                      child: _quickCategory(
                        context,
                        emoji: c.icon,
                        name: c.name,
                        tint: tint,
                        onTap: () {
                          ref.read(historyFilterProvider.notifier).state =
                              HistoryFilter(categoryId: c.id);
                          goTab(1);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _quickCategory(
  BuildContext context, {
  required String emoji,
  required String name,
  required Color tint,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: AppRadius.mdAll,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Column(
        children: [
          Container(
            width: AppSpacing.touchMin,
            height: AppSpacing.touchMin,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: CategoryGlyph(
              emoji: emoji,
              size: AppSpacing.touchMin,
              iconSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: AppType.secondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

/// Dua banner insight (pola promo GoPay, isi datanya milik user):
/// kiri = delta vs bulan lalu, kanan = pacing budget + CTA.
/// Banner dibentuk dari data yang benar-benar ada — kalau satu
/// kosong, yang satunya melebar penuh (bukan menyisakan kolom hampa).
class _InsightBanners extends ConsumerWidget {
  const _InsightBanners({
    required this.month,
    required this.totals,
    required this.onGoTab,
  });

  final String month;
  final AsyncValue<(int, int)> totals;
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final budgets = ref.watch(budgetsProvider);
    final banners = <Widget>[];

    // 1) Delta pengeluaran vs bulan lalu (watch provider).
    final prev = ref.watch(_prevMonthExpenseProvider).value;
    final cur = totals.value?.$2;
    if (prev != null && prev > 0 && cur != null) {
      final prevKey = shiftMonth(month, -1);
      final diff = ((cur - prev) / prev * 100).round();
      final txt = diff == 0
          ? 'Pengeluaran sama seperti ${monthLabel(prevKey)}'
          : diff > 0
          ? 'Pengeluaran naik $diff% vs ${monthLabel(prevKey)}'
          : 'Pengeluaran turun ${-diff}% vs ${monthLabel(prevKey)}';
      // Sub-line insight: selisihnya berapa rupiah.
      final deltaRp = (cur - prev).abs();
      final sub = diff == 0
          ? 'pengeluaran ${display.money(prev)} bulan lalu'
          : diff < 0
          ? '${display.money(deltaRp)} lebih sedikit keluar'
          : '${display.money(deltaRp)} lebih banyak keluar';
      banners.add(
        _bannerBox(
          context,
          gradient: _accentGradient(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                txt,
                style: AppType.secondaryStrong(
                  context,
                ).copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                sub,
                style: AppType.labelMuted(
                  context,
                ).copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (onGoTab != null)
                _bannerPill(
                  context,
                  label: 'Lihat laporan',
                  onTap: () => onGoTab!(3),
                ),
            ],
          ),
        ),
      );
    }

    // 2) Budget bulan ini — plus ajakan saat belum ada (CTA → tab).
    final list = budgets.value;
    if (list != null && list.isEmpty) {
      if (onGoTab != null) {
        banners.add(
          _bannerBox(
            context,
            bg: _darkBanner,
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum ada budget bulan ini',
                  style: AppType.secondaryStrong(
                    context,
                  ).copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.s4),
                _bannerPill(
                  context,
                  label: 'Atur budget',
                  onTap: () => onGoTab!(2),
                ),
              ],
            ),
          ),
        );
      }
    } else if (list != null) {
      final limit = list.fold<int>(0, (s, e) => s + e.budget.limit);
      final spent = list.fold<int>(0, (s, e) => s + e.spent);
      final pct = limit == 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
      final over = spent > limit;
      final warn = !over && pct >= _warnAt;
      // Di atas banner gelap: palet semantik DITERANGKAN supaya bar
      // dan teks status tetap kontras (primary/error mentah gelap).
      final barColor = over
          ? Color.lerp(AppColors.expenseOf(context), Colors.white, 0.35)!
          : warn
          ? _warnAmber
          : Color.lerp(AppColors.incomeOf(context), Colors.white, 0.45)!;
      final status = over
          ? 'Lewat budget'
          : warn
          ? 'Hampir habis'
          : 'Aman bulan ini';
      banners.add(
        _bannerBox(
          context,
          bg: _darkBanner,
          border: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Budget ${monthLabel(month)}',
                      style: AppType.labelMuted(
                        context,
                      ).copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Flexible(
                    child: Text(
                      status,
                      style: AppType.secondary(
                        context,
                      ).copyWith(color: barColor, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              AppProgress(value: pct, color: barColor, height: 8),
              const SizedBox(height: AppSpacing.s4),
              Text(
                '${display.money(spent)} dari ${display.money(limit)}',
                style: AppType.secondary(
                  context,
                ).copyWith(color: Colors.white.withValues(alpha: 0.92)),
              ),
              if (onGoTab != null)
                _bannerPill(context, label: 'Atur', onTap: () => onGoTab!(2)),
            ],
          ),
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: Row(
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s12),
            Expanded(child: banners[i]),
          ],
        ],
      ),
    );
  }
}

/// Kartu banner: gradien aksen (insight utama) atau gelap netral.
Widget _bannerBox(
  BuildContext context, {
  required Widget child,
  Color? bg,
  Gradient? gradient,
  bool border = false,
}) {
  return Container(
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(AppSpacing.s12),
    decoration: BoxDecoration(
      color: gradient == null ? bg : null,
      gradient: gradient,
      borderRadius: AppRadius.xlAll,
      border: border ? Border.all(color: AppColors.borderOf(context)) : null,
    ),
    child: child,
  );
}

/// Tombol pil putih di atas banner gelap.
Widget _bannerPill(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(999),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.40)),
  );
  return Material(
    color: Colors.black.withValues(alpha: 0.30),
    shape: shape,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: AppSpacing.touchMin,
        child: Center(
          child: Text(
            label,
            style: AppType.secondary(
              context,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );
}

/// Tile metrik sebaris (mockup ala GoPay): Masuk / Keluar bulan +
/// Sisa budget. Nilai memakai palet semantik tunggal
/// (incomeOf/expenseOf); Masuk/Keluar di-gate pengaturan tampilan,
/// ringkasan harian pindah ke [_DailyStrip].
class _StatTiles extends ConsumerWidget {
  const _StatTiles({required this.month, required this.totals});

  final String month;
  final AsyncValue<(int, int)> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final showTotals = ref.watch(showMonthTotalsProvider).value ?? true;
    final budgets = ref.watch(budgetsProvider);

    final tiles = <Widget>[];
    final t = totals.value;
    if (showTotals && t != null) {
      tiles.add(
        _tile(
          context,
          child: _MiniStat(
            label: 'Masuk ${monthAbbrLabel(month)}',
            value: display.signed(t.$1, isExpense: false),
            valueColor: AppColors.incomeOf(context),
          ),
        ),
      );
      tiles.add(
        _tile(
          context,
          child: _MiniStat(
            label: 'Keluar ${monthAbbrLabel(month)}',
            value: display.signed(t.$2, isExpense: true),
            valueColor: AppColors.expenseOf(context),
          ),
        ),
      );
    }
    // Tile ketiga: SISA BUDGET (mockup ala GoPay). Ringkasan "Hari ini"
    // pindah ke seksi Terakhir dicatat supaya baris ini tetap 3 kolom.
    final items = budgets.value;
    final totalLimit = (items ?? const []).fold<int>(
      0,
      (s, b) => s + b.budget.limit,
    );
    final totalSpent = (items ?? const []).fold<int>(0, (s, b) => s + b.spent);
    final hasBudget = items?.isNotEmpty ?? false;
    final sisa = totalLimit - totalSpent;
    final daysLeft = _daysLeftInMonth(month);
    tiles.add(
      _tile(
        context,
        child: _MiniStat(
          label: 'SISA BUDGET',
          value: !hasBudget
              ? '—'
              : sisa < 0
              ? '-${display.money(sisa.abs())}'
              : display.money(sisa),
          valueColor: !hasBudget
              ? AppColors.mutedOf(context)
              : sisa < 0
              ? AppColors.expenseOf(context)
              : null,
          sub: !hasBudget
              ? 'belum diatur'
              : sisa < 0
              ? 'lewat batas'
              : daysLeft <= 0
              ? 'selesai'
              : '$daysLeft hari lagi',
        ),
      ),
    );

    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == tiles.length - 1 ? 0 : AppSpacing.s8,
                ),
                child: tiles[i],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _tile(BuildContext context, {required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.s12),
    decoration: BoxDecoration(
      color: AppColors.surfaceOf(context),
      border: Border.all(color: AppColors.borderOf(context)),
      borderRadius: AppRadius.mdAll,
    ),
    child: child,
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.sub,
  });
  final String label;
  final String value;

  /// Warna semantik tunggal untuk nilai (mis. incomeOf/expenseOf).
  final Color? valueColor;

  /// Baris kecil di bawah nilai (mis. rincian hari ini).
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.labelMuted(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppType.amount(context).copyWith(color: valueColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub!,
            style: AppType.labelMuted(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
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
            subtitle:
                'Setiap rupiah yang dicatat bikin gambaran keuanganmu makin jelas. Yuk mulai dari satu transaksi!',
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
                          const SizedBox(height: 6),
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
                      style: AppType.amount(context, size: 14),
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
          child: Row(
            children: [
              Text('Hari ini', style: AppType.labelMuted(context)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'masuk ${display.signed(d.$1, isExpense: false)} · '
                  'keluar ${display.signed(d.$2, isExpense: true)}',
                  style: AppType.secondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
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
            title: 'Hari ini belum ada catatan',
            subtitle:
                'Belum ada transaksi — hari yang tenang juga patut dirayakan. Ketuk “Catat” saat ada pemasukan atau pengeluaran.',
          );
        }
        final groups = <DateTime, List<TxWithCategory>>{};
        for (final tx in list) {
          final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
          (groups[d] ??= []).add(tx);
        }
        final entries = groups.entries.toList();
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
                  style: AppType.secondaryStrong(context),
                ),
              ),
              for (final tx in entries[i].value)
                TxTile(
                  tx: tx,
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
