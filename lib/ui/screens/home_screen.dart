import 'dart:math';

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
import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../display.dart';
import '../format.dart';
import '../greeting.dart';
import '../widgets/tx_tile.dart';
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

/// Streak pencatatan: jumlah hari BERURUTAN (mundur dari hari ini)
/// yang punya ≥1 transaksi. Mesin retensi B2C (kartu streak + misi).
///
/// Reaktif seperti [balanceProvider]: dengarkan tabel transaksi, hitung
/// ulang tiap ada perubahan. Read-only (customSelect DISTINCT tanggal),
/// tidak menyentuh schema/query lain.
final _streakProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  return db
      .select(db.transactions)
      .watch()
      .asyncMap((_) => _calcStreak(db));
});

Future<int> _calcStreak(AppDatabase db) async {
  // Hitung di Dart murni (tanpa SQL mentah): ambil tanggal semua
  // transaksi hidup, petakan ke hari lokal. Aman untuk semua backend
  // drift + tidak menambah query baru ke database.dart.
  final rows = await (db.select(
    db.transactions,
  )..where((t) => t.deletedAt.isNull())).get();
  final days = <DateTime>{
    for (final r in rows) DateTime(r.date.year, r.date.month, r.date.day),
  };
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  // Hari ini belum catat → streak dihitung dari kemarin (belum putus).
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
    if (streak > 3650) break;
  }
  return streak;
}

/// Beranda: kepala sapaan berwarna aksen, kartu saldo gradien aksen,
/// nav bulan (selalu tampil), tile metrik, banner insight,
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

    // Sapaan production-grade (v1.18): berbasis waktu + resolusi nama
    // (setting manual → nama akun Google → polos). Tanpa nama mockup.
    final manualName = ref.watch(displayNameProvider).value ?? '';
    final googleName = ref.watch(familySessionProvider).value?.displayName;
    final greetName = resolveGreetingName(
      manualName: manualName,
      googleName: googleName,
    );
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
                          // Avatar inisial — identitas visual saja (bukan tombol).
                          // Satu-satunya pintu Pengaturan adalah ikon gear
                          // di kanan (menghindari duplikasi avatar+gear yang
                          // membuka layar sama + tooltip 'Profil' yang salah
                          // di screen reader).
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  _avatarInitial(greetName ?? ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
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
                                        greetingText(
                                          now,
                                          manualName: manualName,
                                          googleName: googleName,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.screenTitle(context)
                                            .copyWith(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                      ),
                                    ),
                                    // Mahkota hanya bila ada nama (sapaan polos
                                    // tanpa nama = tanpa mahkota).
                                    if (greetName != null) ...[
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
                          // Gear — satu-satunya pintu Pengaturan di Beranda
                          // (lonceng lama dihapus: ia cuma snackbar
                          // "Belum ada notifikasi" — bukan jalan ke fitur
                          // Pengingat harian yang hidup di Pengaturan).
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
                  child: _HeroCard(balance: balance, month: month),
                ),
              ],
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Nav bulan SELALU tampil (semua tab Beranda/Riwayat/Budget/
                  // Laporan berbagi selectedMonthProvider yang sama): tanpa
                  // ini, label "Masuk OKT / Keluar OKT" tidak punya kontrol
                  // bulan — chicken-and-egg v1.13.x. Chip bulan jadi
                  // penanda konteks + jalan pulang saat menjelajah.
                  SliverToBoxAdapter(
                    key: const ValueKey('home:monthnav'),
                    child: _pad(
                      AppMonthNav(month: month, onShift: shift),
                      top: AppSpacing.s16,
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:tiles'),
                    child: _pad(
                      _StatTiles(month: month, totals: totals),
                      stagger: 1,
                    ),
                  ),
                  if (onGoTab != null)
                    SliverToBoxAdapter(
                      key: const ValueKey('home:debts'),
                      child: _pad(_DebtCard(onGoTab: onGoTab), stagger: 2),
                    ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:banners'),
                    child: _pad(
                      _InsightBanners(
                        month: month,
                        totals: totals,
                        onGoTab: onGoTab,
                      ),
                      stagger: 2,
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:streak'),
                    child: _pad(const _StreakCard(), stagger: 3),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('home:quickadd'),
                    child: _pad(const _QuickAdd(), stagger: 4),
                  ),
                  // Top kategori + terakhir dicatat: tanpa quick-actions,
                  // strip kategori ganda, & banner ganda, judul seksi sudah
                  // terlihat di layar pertama (fold ~764px di 390x844).
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
                        stagger: 5,
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
                        stagger: 6,
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
///
/// B2C v1.20: [stagger] > 0 membungkus konten dengan entrance
/// fade+geser (lihat [Stagger]) — teks/key/logika tidak berubah.
Widget _pad(Widget child, {double top = 0, int stagger = 0}) {
  final content =
      stagger <= 0 ? child : Stagger(index: stagger, child: child);
  return Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.page, top, AppSpacing.page, 0),
    child: content,
  );
}

/// Inisial avatar header (lingkaran inisial di kiri sapaan).
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

/// Kartu saldo: gradien aksen + saldo SEMUA WAKTU + tombol raksasa.
///
/// B2C: kartu kemenangan ala GoPay — saldo count-up, pacing budget bulan
/// ini DIHITUNG DI AWAL (baris ringkas + bar, detail di tile + tab
/// Budget), SATU tombol '+ Catat keluar' full-width 56px (THE action)
/// + link '+ Pemasukan' sekunder. Teks pil + key 'home:hero' + gradien
/// dikunci home_design_test — tidak diubah.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.balance, required this.month});

  final AsyncValue<int> balance;

  /// Bulan aktif (untuk label budget di hero).
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideBalanceProvider).value ?? false;
    final display = ref.watch(displayPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    // Budget bulan ini untuk baris pacing di hero (sumber sama dengan
    // tile 'Sisa budget': budgetsProvider — tanpa query baru).
    final budgetItems = ref.watch(budgetsProvider).value;
    final hasBudget = budgetItems?.isNotEmpty ?? false;
    final bLimit = (budgetItems ?? const []).fold<int>(
      0,
      (s, e) => s + e.budget.limit,
    );
    final bSpent = (budgetItems ?? const []).fold<int>(
      0,
      (s, e) => s + e.spent,
    );
    final pct = bLimit == 0 ? 0.0 : (bSpent / bLimit).clamp(0.0, 1.0);
    final pctLabel = (pct * 100).round();
    final mShort = monthAbbrLabel(month);

    return Container(
      key: const ValueKey('home:hero'),
      clipBehavior: Clip.antiAlias,
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
          // B2C v1.20: kilau dekoratif (lingkaran putih samar) — di
          // bawah konten, tidak mengubah decoration (test kontras baca
          // gradient Container ini) maupun teks/key/logika.
          Positioned(
            top: -56,
            right: -32,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -72,
            left: -28,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Penanda horizon: angka ini ALL-TIME, bukan bulan ini
                // (v1.13.x "SALDO MYWALLET" tanpa konteks — tile di bawah
                // justru bulanan, dua horizon tercampur tanpa pembeda).
                'SALDO SAAT INI',
                style: AppType.labelMuted(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              balance.when(
                loading: () => const AppSkeleton(lines: 1),
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
                // B2C: saldo count-up dari 0 — rasa "menang" tiap buka
                // aplikasi. TweenAnimationBuilder (tanpa controller/
                // timer) — aman untuk fake_async test. Hide-balance
                // + error path tidak berubah.
                data: (b) => _CountUp(
                  value: b,
                  format: (v) => hide ? 'Rp••••••' : display.money(v),
                ),
              ),
              // Budget bulan ini DIHITUNG DI AWAL: baris pacing ringkas +
              // bar di dalam hero (detail tetap di tile + tab Budget).
              if (hasBudget) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  'Budget $mShort · $pctLabel% terpakai',
                  style: AppType.secondary(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s8),
                AppProgress(value: pct, color: Colors.white, height: 8),
              ],
              const SizedBox(height: AppSpacing.s16),
              // B2C: SATU tombol raksasa full-width 56px (THE action —
              // pola tombol order GoFood). Teks '+ Catat keluar' dikunci
              // test; tujuan tetap form pengeluaran.
              _megaButton(
                context,
                label: '+ Catat keluar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const TxFormScreen(startAsExpense: true),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              // Pemasukan = link sekunder di bawah tombol utama (bukan
              // pesaing setara). Teks '+ Pemasukan' dikunci test.
              Center(
                child: _incomeLink(
                  context,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const TxFormScreen(startAsExpense: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Mata toggle saldo — 48px penuh (AppSpacing.touchMin):
          // cukup di dalam kartu (right 0), tidak 2px dari tepi.
          Positioned(
            top: 0,
            right: 0,
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

/// Saldo count-up B2C: angka menghitung naik 0 → [value] sekali saat
/// pertama tampil. TweenAnimationBuilder (tanpa controller/timer —
/// preseden [Stagger]) + hormati disableAnimations. Test fake_async aman.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.format});
  final int value;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final style = AppType.balance(
      context,
    ).copyWith(color: Colors.white, fontSize: 29);
    if (AppMotion.animationsOff(context)) {
      return Text(format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.easeOut,
      builder: (context, v, _) => Text(format(v.round()), style: style),
    );
  }
}

/// Tombol raksasa hero B2C: full-width 56px putih solid, teks aksen
/// pekat (rumus warna sama dengan pil solid lama → kontras terjaga).
/// Teks '+ Catat keluar' dikunci home_design_test.
Widget _megaButton(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    elevation: 4,
    shadowColor: Colors.black.withValues(alpha: 0.25),
    child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 56,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.amount(context, size: 16).copyWith(
              color: _accentStop(context, 0.45),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Link pemasukan sekunder di bawah tombol raksasa: teks putih + panah,
/// target sentuh 48px. Teks '+ Pemasukan' dikunci home_design_test
/// (dulu ghost pil — kini link agar tombol utama tak punya pesaing).
Widget _incomeLink(
  BuildContext context, {
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    borderRadius: AppRadius.smAll,
    child: SizedBox(
      height: AppSpacing.touchMin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '+ Pemasukan',
              style: AppType.secondary(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
        ],
      ),
    ),
  );
}

/// Kartu streak B2C: mesin retensi — N hari berurutan + dots 7 +
/// misi hari ini. Streak 0 = ajakan mulai (bukan kartu kosong).
/// Sumber: [_streakProvider] (hitung dari transaksi, tanpa schema baru).
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(_streakProvider);
    return streak.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s16),
        child: AppSkeleton(lines: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (n) {
        final title = n <= 0
            ? 'Mulai streak hari ini'
            : n == 1
            ? 'Streak 1 hari!'
            : 'Streak $n hari!';
        final sub = n <= 0
            ? 'Catat 1 transaksi — besok lanjut lagi'
            : 'Catat lagi hari ini biar jadi ${n + 1}';
        // Dots 7: N terisi (capped 7), sisanya kosong.
        final filled = n.clamp(0, 7);
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              border: Border.all(
                color: n > 0
                    ? _warnAmber.withValues(alpha: 0.7)
                    : AppColors.borderOf(context),
              ),
              borderRadius: AppRadius.xlAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Ikon api vektor (bukan emoji 🔥): font test/
                          // golden (Segoe/DejaVu) tidak punya glyph emoji
                          // → tofu '[]' di golden QA.
                          Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: n > 0
                                ? _warnAmber
                                : AppColors.mutedOf(context),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Flexible(
                            child: Text(
                              title,
                              style: AppType.amount(context, size: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        sub,
                        style: AppType.secondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < filled
                                    ? _warnAmber
                                    : AppColors.subtleOf(context),
                                border: i < filled
                                    ? null
                                    : Border.all(
                                        color: AppColors.borderOf(context),
                                      ),
                              ),
                            ),
                            if (i < 6)
                              const SizedBox(width: AppSpacing.s4),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Text(
                  '$n/7',
                  style: AppType.balance(context).copyWith(
                    fontSize: 22,
                    color: n > 0
                        ? _warnAmber
                        : AppColors.mutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Chip nominal Catat Kilat di atas kartu TERANG: isi = surface kartu +
/// border netral + teks aksen pekat. Beda dari [_pillButton] ghost
/// (putih 15% + teks putih) yang hanya benar di atas gradien gelap hero.
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: AppSpacing.touchMin,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.secondary(context).copyWith(
                  color: _accentStop(context, 0.45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Catat Kilat B2C: 4 chip nominal → form pengeluaran TERISI nominal.
/// Scroll horizontal (aman viewport 300px — pola chip Riwayat).
/// Label 'Catat kilat' unik (tidak bentrok dengan test kategori).
class _QuickAdd extends StatelessWidget {
  const _QuickAdd();

  static const _amounts = [10000, 25000, 50000, 100000];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catat kilat', style: AppType.sectionTitle(context)),
        const SizedBox(height: AppSpacing.groupGap),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _amounts.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s8),
                // Varian kartu-terang SENDIRI (bukan _pillButton ghost):
                // ghost = isi putih 15% + teks putih, didesain untuk di
                // atas gradien GELAP hero → di atas kartu terang jadi
                // putih-di-atas-putih / invisible (bug QA golden).
                _QuickChip(
                  label: formatRpCompact(_amounts[i]),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TxFormScreen(
                        startAsExpense: true,
                        initialAmount: _amounts[i],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
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
    final prevAsync = ref.watch(_prevMonthExpenseProvider);
    final prevLoading = prevAsync.isLoading;
    final prev = prevAsync.value;
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
                _bannerCta(
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
    // Ringkas: angka sisa sudah ada di tile "Sisa budget" di atas,
    // banner hanya status pacing + bar (tanpa mengulang "Rp x dari Rp y").
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
                _bannerCta(
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
              Text(
                'Budget ${monthLabel(month)}',
                style: AppType.labelMuted(
                  context,
                ).copyWith(color: Colors.white.withValues(alpha: 0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s8),
              AppProgress(value: pct, color: barColor, height: 8),
              const SizedBox(height: AppSpacing.s4),
              Text(
                // Satu baris status: angka ringkas (sisa detail ada di tile
                // "Sisa budget" di atas + tab Budget) + status pacing.
                '$status · ${display.money(spent)} dari ${display.money(limit)}',
                style: AppType.secondary(context).copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              if (onGoTab != null)
                _bannerCta(context, label: 'Atur', onTap: () => onGoTab!(2)),
            ],
          ),
        ),
      );
    }

    if (banners.isEmpty) {
      // Masih loading (salah satu provider belum ada data): skeleton
      // setinggi banner agar layout tidak lompat saat data datang
      // (v1.13.x SizedBox.shrink di sini, banner "muncul" belakangan).
      final anyLoading =
          totals.isLoading || budgets.isLoading || prevLoading;
      if (!anyLoading) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s16),
        child: AppSkeleton(lines: 2),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      // start: kedua banner mulai dari y yang sama sehingga judulnya
      // sejajar (v1.13.x center → offset 20px atas-bawah di
      // dark/no-budget, terukur di golden). Bukan stretch: stretch di
      // dalam scroll vertikal = height tak terbatas → crash layout.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

/// CTA teks di dalam banner insight — menggantikan _bannerPill v1.13.x
/// (pil putih 48px dengan 1-2 kata: "Atur", "Lihat laporan"). Pil penuh
/// untuk 1-2 kata boros ruang & meniru tombol primer; link teks + ikon
/// panah cukup sebagai affordance di dalam kartu yang sudah jelas
/// bisa diketuk. Target sentuh 48px dipertahankan.
Widget _bannerCta(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: AppRadius.smAll,
    child: SizedBox(
      height: AppSpacing.touchMin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FIX CI Ubuntu 9 Okt 2026 (7 gagal home_design_test):
          // font DejaVu runner ~20% lebih lebar dari Segoe Windows →
          // Row CTA ("Lihat laporan" + panah) jebol 32px di banner
          // setengah layar (w<=149). Flexible + ellipsis = muat di
          // font lebar + viewport 300px + font-scale besar HP kecil.
          Flexible(
            child: Text(
              label,
              style: AppType.secondary(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          const Icon(
            Icons.arrow_forward,
            size: 16,
            color: Colors.white,
          ),
        ],
      ),
    ),
  );
}

/// Tile metrik sebaris: Masuk / Keluar bulan berjalan + Sisa budget.
/// Nilai memakai palet semantik tunggal (incomeOf/expenseOf);
/// Masuk/Keluar di-gate pengaturan tampilan, ringkasan harian pindah
/// ke [_DailyStrip].
class _StatTiles extends ConsumerWidget {
  const _StatTiles({required this.month, required this.totals});

  final String month;
  final AsyncValue<(int, int)> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final showTotals = ref.watch(showMonthTotalsProvider).value ?? true;
    final budgets = ref.watch(budgetsProvider);
    // Singkatan bulan mengikuti bulan yang sedang dijelajah
    // (chip AppMonthNav di atas selalu menunjukkan konteks penuh).
    final mLabel = monthAbbrLabel(month);

    final tiles = <Widget>[];
    final t = totals.value;
    if (showTotals && t != null) {
      tiles.add(
        _tile(
          context,
          child: _MiniStat(
            label: 'Masuk $mLabel',
            value: display.signed(t.$1, isExpense: false),
            valueColor: AppColors.incomeOf(context),
          ),
        ),
      );
      tiles.add(
        _tile(
          context,
          child: _MiniStat(
            label: 'Keluar $mLabel',
            value: display.signed(t.$2, isExpense: true),
            valueColor: AppColors.expenseOf(context),
          ),
        ),
      );
    }
    // Tile ketiga: ringkasan budget bulan yang sedang dijelajah.
    // Tanpa budget yang diatur, tile menyusut jadi satu baris ajakan
    // (bukan kartu "— / belum diatur" setinggi tile bernilai).
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
          label: 'Sisa budget',
          value: !hasBudget
              ? 'Belum diatur'
              : sisa < 0
              ? '-${display.money(sisa.abs())}'
              : display.money(sisa),
          valueColor: !hasBudget
              ? AppColors.mutedOf(context)
              : sisa < 0
              ? AppColors.expenseOf(context)
              : null,
          sub: !hasBudget
              ? null
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
      // s16 = jarak blok standar (monthnav, banner); sectionGap (24) hanya
      // antar SEKSI besar (topcats, recent) — satu ritme, bukan 3 token
      // campur (v1.13.x s12/s16/s24 → jarak 20/35/43px tak beraturan).
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      // start (bukan center): semua tile mulai dari y yang sama sehingga
      // label sejajar (v1.13.x center → tile tanpa sub-line bergeser 10px,
      // terukur di golden). Bukan stretch: stretch di dalam scroll
      // vertikal memaksa height tak terbatas ke children → crash layout.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

/// Kartu ringkas utang-piutang di Beranda (v1.15): sisa utang vs piutang.
/// Kosong (keduanya 0) = tidak tampil. Tap = tab Utang (indeks 4).
class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.onGoTab});
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(debtSummaryProvider);
    final display = ref.watch(displayPrefsProvider);
    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        final utang = s.$1;
        final piutang = s.$2;
        if (utang == 0 && piutang == 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s12),
          child: AppSection(
            title: 'Utang & piutang',
            trailing: onGoTab == null
                ? null
                : TextButton(
                    onPressed: () => onGoTab!(4),
                    child: const Text('Kelola'),
                  ),
            child: InkWell(
              onTap:
                  onGoTab == null ? null : () => onGoTab!(4),
              borderRadius: AppRadius.mdAll,
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Sisa utang',
                      value: display.money(utang),
                      valueColor: AppColors.expenseOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _MiniStat(
                      label: 'Sisa piutang',
                      value: display.money(piutang),
                      valueColor: AppColors.incomeOf(context),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
        // FittedBox scaleDown: nominal panjang (mis. +Rp10.188.000 di
        // kolom 1/3 @390px) MENGECIL, bukan kepotong '...' (bug QA
        // golden). Teks utuh tetap ada → find.text test tidak berubah.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppType.amount(context).copyWith(color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
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
            title: 'Belum ada transaksi',
            subtitle: 'Ketuk + Catat keluar saat ada pemasukan atau pengeluaran.',
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
