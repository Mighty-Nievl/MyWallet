/// Changelog in-app MyWallet — SATU-SATUNYA sumber teks changelog.
///
/// Aturan wajib tiap build / naik versi:
/// - Urutan terbaru dulu.
/// - `version` format `vX.Y.Z`, cocok dengan `version:` di pubspec.yaml
///   (tanpa `+build`, contoh pubspec `1.9.0+14` -> `v1.9.0`).
/// - `date` format `8 Okt 2026`, cocok dengan `docs/07-Rilis-dan-Obtainium.md`.
/// - Tiap naik versi di pubspec WAJIB tambah entri baru paling atas.
/// - `user`: bahasa manusia, 1-2 kalimat, menjawab "apa untungnya buat
///   saya?". DILARANG istilah internal (uuid, skema DB, plugin, minSdk,
///   nama paket/secret/CI, singkatan Fase tanpa penjelasan).
///   Dijaga otomatis oleh `test/changelog_test.dart`.
/// - `tech`: detail teknis untuk yang penasaran — tampil collapsed
///   ("Detail teknis") di halaman Changelog, tidak mengganggu pembaca biasa.
/// - `breaking`: hanya bila update butuh tindakan user (backup dulu,
///   install baru, izin baru). Wajib menyebut jalan keluarnya.
/// - Halaman Changelog (`lib/ui/screens/changelog_screen.dart`) wajib
///   ambil teks dari sini, JANGAN hardcode lagi.
/// - `docs/07-Rilis-dan-Obtainium.md` + README wajib diupdate bareng.
/// - `test/changelog_test.dart` gagal bila entri teratas beda dengan pubspec.
const appChangelog = <({String version, String date, String user, String tech, String? breaking})>[
  (
    version: 'v1.40.0',
    date: '23 Okt 2026',
    user:
        'Mencatat sekarang bisa satu kolom: tulis "makan 25 ribu" di Catatan, '
        'nominalnya terbaca sendiri saat disimpan — tidak perlu pindah kolom '
        'atau mengetik ulang angkanya. Kalau kamu mengisi nominal sendiri, '
        'yang kamu ketik selalu menang.',
    tech:
        'v1.40.0: `parseQuickInput` (`lib/data/quick_parse.dart`) murni string '
        '→ angka, urutan prioritas: ribuan bertitik `\\d{1,3}(?:\\.\\d{3})+`, '
        'angka + satuan (`ribu|ribuan|rb|k|juta|jt`, koma/titik desimal), lalu '
        'angka polos >= 4 digit. Angka < 1000 tanpa satuan dan > Rp1 triliun '
        'mengembalikan null — menebak di situ lebih berbahaya daripada meminta '
        'nominal. Sisa teks jadi catatan ("Rp" yatim dibuang, spasi dirapikan). '
        'UI: `tx_form_screen` menampilkan helper live "Terbaca Rp25.000 — dipakai '
        'saat simpan" (listener pada `_amountCtrl` mematikannya begitu user '
        'mengetik nominal) dan `_save()` memakai hasil parse hanya bila '
        '`parseRp` = 0, lalu mengisi kolom nominal. 15 test '
        '`quick_parse_test.dart`.',
    breaking: null,
  ),
  (
    version: 'v1.39.0',
    date: '23 Okt 2026',
    user:
        'Data keuanganmu sekarang dicadangkan otomatis setiap hari ke dalam '
        'HP — lima salinan terakhir disimpan. Kalau ada yang salah catat, '
        'file rusak, atau HP bermasalah, kamu bisa memulihkannya dari '
        'Pengaturan → Kelola tanpa harus ingat menekan tombol backup. '
        'Bisa dimatikan kapan saja kalau tidak mau.',
    tech:
        'v1.39.0: dulu satu-satunya salinan adalah tombol `backupDb()` yang '
        'butuh buka layar + pilih folder, jadi realitanya jarang ditekan; '
        'sync Firestore bukan pengganti karena hanya dompet `isShared` yang '
        'dikirim. Sekarang `AutoBackupController` (tanpa widget, injected '
        'callbacks seperti AutoSyncController) dipicu `AutoBackupBinder` '
        'pada `start`/`resume`, maksimal sekali per 20 jam, diam bila switch '
        'mati, tidak pernah melempar, dan satu percobaan pada satu waktu '
        '(`_busy`). Penulisan: `PRAGMA wal_checkpoint(TRUNCATE)` lalu salin '
        '`mywallet.sqlite` ke `backups/mywallet-auto-YYYYMMDD-HHMM.sqlite` '
        'di dokumen app, rotasi 5 terbaru (nama = urutan waktu, tanpa baca '
        'mtime). Waktu terakhir di `last_backup_at` (millis), switch di '
        '`auto_backup` (default ON). UI Kelola: status "Backup terakhir" + '
        'tombol "Sekarang" yang melewati jatah, daftar salinan bisa dipilih '
        'untuk restore (dialog konfirmasi sama persis dengan restore manual '
        'lewat `restoreFromPath`). Test baru `auto_backup_test.dart` (16 '
        'kasus: jatah, switch, gagal tulis, rotasi, label, binder). 350 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.7',
    date: '22 Okt 2026',
    user:
        'Kalau filternya "Harian", "Pengeluaran hari ini" sekarang tampil di '
        'atas "Terakhir dicatat" — jadi yang pertama terlihat adalah ke mana '
        'uang pergi hari ini, bukan daftar transaksinya. Untuk Mingguan, '
        'Bulanan, dan Tahunan urutannya tetap seperti sebelumnya.',
    tech:
        'v1.38.7: urutan dua section Beranda kini bergantung periode. Di '
        'home_screen.dart blok `home:recent` dan `home:topcats` diangkat jadi '
        '`recentSlivers`/`topcatSlivers` lokal lalu di-spread kondisional '
        'lewat `dailyFirst = period.kind == PeriodKind.harian`. Alasan: untuk '
        'rentang sehari daftar transaksi cuma 2-3 baris dan `_DailyStrip` di '
        'dalam "Terakhir dicatat" sudah menampilkan total harian, jadi angka '
        'dobel bila keduanya berurutan seperti pola bulanan; untuk '
        'sebulan/setahun daftarnya panjang sehingga kategori yang ditaruh di '
        'atas berarti user menggulir dua kali. Test baru di '
        'home_design_test.dart: harian topcats.dy < recent.dy, bulanan tetap '
        'recent.dy < topcats.dy. 334 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.6',
    date: '22 Okt 2026',
    user:
        'Label bulan di navigasi periode tidak lagi tampak abu-abu "mati" — '
        'sekarang terbaca seterang teks lain. Chip periode yang sedang aktif '
        'juga dapat garis tegas, jadi kelihatan mana yang dipilih tanpa harus '
        'menebak dari warna latar.',
    tech:
        'v1.38.6: (1) PeriodNav memakai onPressed: isCurrent ? null : ... '
        'sehingga ActionChip jatuh ke state disabled dan M3 menimpa warna '
        'label jadi 38% onSurface — terukur 3,4:1 di atas pill #F0F8F0 '
        '(gagal AA) walau style sudah onSurface eksplisit. "Oktober 2026" '
        'adalah state default aplikasi, jadi label yang paling sering dilihat '
        'justru yang tampak tidak bisa dipakai. Sekarang selalu aktif, ketuk '
        'saat sudah di periode berjalan = no-op. (2) Seleksi chip periode '
        'dulu hanya fill mint vs abu-abu (1,16:1) sementara border idle '
        '7,36:1 di #FAFAFA, jadi elemen terpilih adalah yang paling pucat. '
        'Idle TIDAK ditipiskan (7,36:1 sudah benar untuk batas komponen dan '
        'ambang 3:1 di test/contrast_test.dart akan merah); yang dinaikkan '
        'sisi terpilih: BorderSide(onPrimaryContainer, width 1.5) ~13:1 vs '
        'background. 333 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.5',
    date: '22 Okt 2026',
    user:
        'Data antar-HP kini menyusul sendiri: aplikasi mencoba menyinkronkan '
        'saat dibuka, saat kembali dari background, dan begitu sinyal '
        'kembali. Tidak perlu lagi membuka menu Keluarga lalu menekan '
        '"Sinkronkan" — tombolnya tetap ada untuk sync paksa.',
    tech:
        'v1.38.5: syncNow() sebelumnya hanya dipanggil dari '
        'family_screen.dart:947, jadi sync_engine(512)+sync_service(224) '
        'bergantung pada satu tombol di satu layar. Baru: '
        'lib/data/auto_sync.dart — AutoSyncController murni (tanpa widget, '
        'tanpa WidgetRef; dependensi masuk lewat konstruktor) dengan aturan: '
        'start sekali per sesi, resume/online dijatah minInterval 2 menit, '
        'diam saat offline, diam tanpa householdId, dan tidak pernah '
        'melempar (gagal = SyncState.failed). Penghitung '
        'runs/skippedOffline/skippedNotReady/throttled untuk diagnosa. '
        'Pemicu: lib/ui/widgets/auto_sync_binder.dart (postFrame start, '
        'AppLifecycleState.resumed, transisi isOfflineProvider true→false), '
        'dipasang sebagai home di app.dart. Hasil sync latar ditulis ke '
        'syncStateProvider supaya layar Keluarga ikut menampilkan. '
        'test/migration_test.dart baru: v4→v5 (is_shared ditambah, baris + PK '
        '+ saldo utuh, default privat) dibangun lewat NativeDatabase.memory '
        '(setup:) + PRAGMA user_version=4, dan onCreate v5 (seed kategori + '
        'dompet Utama). test/auto_sync_test.dart baru: 7 kasus controller + 3 '
        'widget. 332 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.4',
    date: '22 Okt 2026',
    user:
        'Hapus transaksi kini tidak lagi minta konfirmasi dulu: sekali ketuk '
        'langsung hilang, lalu muncul tombol "Urungkan" selama 6 detik kalau '
        'salah pencet. Menu "Budget" berganti nama jadi "Anggaran" supaya '
        'sebahasa dengan bagian aplikasi lainnya.',
    tech:
        'v1.38.4: hapus transaksi itu soft-delete (deletedAt tombstone), jadi '
        'dialog "tidak bisa dikembalikan" di tx_form_screen berbohong ke '
        'user. _delete() sekarang: deleteTransaction -> pop -> SnackBar 6 '
        'detik + SnackBarAction "Urungkan" -> restoreTransaction(db, id) yang '
        'mengosongkan deletedAt dan memperbarui updatedAt (biar kebangkitan '
        'menang LWW saat sync). restoreTransaction menerima AppDatabase, '
        'bukan WidgetRef, karena ref widget pemanggil sudah dibuang setelah '
        'pop. Label "Budget" -> "Anggaran" di 8 string (budget_screen: judul, '
        'caption, error, tersimpan, terhapus; account_detail; '
        'home_feature_grid; home_menu_scan_test). test/contrast_test.dart '
        'baru: 20 pasangan token dihitung rasionya untuk light+dark (ambang '
        '4,5:1 teks, 3:1 batas komponen) + penjaga konstanta uji = token '
        'asli; test/tx_delete_undo_test.dart baru. 2 file test baru, 320 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.3',
    date: '22 Okt 2026',
    user:
        'Baris filter waktu di Beranda dan Laporan kini rapi: keempat pilihan '
        '(Harian, Mingguan, Bulanan, Tahunan) terbaca utuh — tidak ada lagi '
        'tulisan yang terpotong di tengah — dan warna tulisannya cukup gelap '
        'untuk dibaca di layar terang. Ikon Kalender pindah ke samping panah '
        'periode, jadi selalu kelihatan dan tidak perlu digeser dulu.',
    tech:
        'v1.38.3: diukur dari screenshot rilis v1.38.2 (1224 px / 390dp = '
        '3,14x). Centang M3 (showCheckmark default) ternyata tak terbaca — '
        'kecerahan 46 vs 68 dari 255, ~1,4:1 — tapi memakan 37dp ruang kiri '
        'vs 17,5dp kanan, dan itulah yang mendorong chip "Tahunan" keluar '
        'viewport sehingga glyph terpotong tanpa elipsis (border kanan ikut '
        'hilang). Centang dimatikan; seleksi dibawa fill + w700. Padding '
        'horizontal 16 -> 12dp: empat label (218,5dp) + padding + jarak = '
        '338,5dp, muat di 358dp sehingga maxScrollExtent = 0 di 390dp '
        '(ListView tetap ada untuk textScaler 2.0). Label idle mutedOf '
        '2,23:1 (gagal AA) -> strongSecondaryOf ~9:1; chip idle fill '
        'lightSubtle + border outline (~4,4:1, dulu 1,91:1); label periode '
        'onSurface eksplisit (dulu 3,88:1). "Kalender" keluar dari '
        'ListView (item ke-5 tak pernah terlihat di 390dp) ke PeriodNav '
        'sebagai IconButton.outlined 44dp, dengan penyeimbang 44dp supaya '
        'grup chevron+label tetap di tengah. Test baru '
        'test/period_switcher_test.dart menjaga keempat klaim itu. 314 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.2',
    date: '22 Okt 2026',
    user:
        'Penunjuk halaman kartu dompet kini bersih mengambang di bawah kartu '
        'saldo: tiga titik putih yang jelas, halaman aktif jadi garis pendek. '
        'Kotak gelap di belakangnya dihapus karena di layar HP hanya terlihat '
        'seperti noda — sekarang tidak ada lagi yang menempel angka saldo.',
    tech:
        'v1.38.2: kapsul scrim (hitam 22%, v1.38.1) dibuang. Diukur dari '
        'screenshot rilis v1.38.1: kartu #126547 vs kapsul #16513D = 1,31:1 '
        '(di bawah 3:1 WCAG 1.4.11 untuk batas komponen) dan memakan 103/494 '
        'px = 21% tinggi kartu untuk tiga titik 16 px. Titik kini langsung di '
        'mesh: aktif putih 7,05:1, non-aktif kDotIdle putih 85% = 4,99:1 '
        '(terendah 3,03:1 di mesh paling terang). Slot 28x32 -> 24x24 (pitch '
        '24, minimum WCAG 2.2 AA) supaya tiga titik terbaca satu grup; tinggi '
        'baris tetap touchMin 48. Kelola jadi AppIconButton bordered:false '
        '(ikon putih polos seperti mata saldo), chip scrim dihapus. Sesuai '
        'test yang sama diperbarui. 309 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.1',
    date: '22 Okt 2026',
    user:
        'Penunjuk halaman kartu dompet kini mengambang rapi di tengah bawah '
        'kartu saldo: halaman aktif tampil sebagai garis pendek, halaman lain '
        'sebagai titik, dan tombol kelola dompet jadi ikon gerigi — layar '
        'jadi lebih lega tanpa baris tambahan di bawah kartu.',
    tech:
        'v1.38.1: indikator halaman + Kelola dipindah jadi overlay di dalam '
        'SizedBox 188 milik carousel (Stack + Positioned bottom s8) → '
        'menghemat 40px hero (baris dot lama 32+8 hilang). Kapsul dot: '
        'Container tinggi 32, padding horizontal s4, AppRadius.pillAll, latar '
        'kDotScrim (hitam 22%) — putih 18% sempat dicoba dan meninggalkan '
        'titik non-aktif 2,88:1 terhadap kapsul (gagal 3:1 WCAG 1.4.11). '
        '_Dot dapat activeColor/inactiveColor (default tetap token): aktif '
        'putih solid, non-aktif putih 78% (kDotIdle) = 4,05-4,83:1 — pembeda '
        'tetap bentuk pill 18×6 vs titik 6×6, bukan warna (WCAG 1.4.1). Slot '
        'dot 28×32 dipertahankan (48px merusak pitch). Kelola: TextButton → '
        'IconButton settings_outlined 32px dalam target sentuh 48px '
        '(touchMin), bottom-right. 1 test baru. 309 test.',
    breaking: null,
  ),
  (
    version: 'v1.38.0',
    date: '22 Okt 2026',
    user:
        'Punya lebih dari satu dompet? Beranda kini punya halaman "Semua '
        'dompet" yang menunjukkan total seluruh uangmu — tidak perlu '
        'menjumlah sendiri. Dan kalau kamu belum pernah mencatat apa pun, '
        'Beranda langsung menawarkan satu tombol "Catat pengeluaran pertama" '
        '(atau scan struk), bukan tumpukan angka Rp0.',
    tech:
        'v1.38.0: AccountCarousel halaman 0 = _AllWalletsCard (balanceProvider) '
        'saat dompet >1; itemCount = list.length+1; onPageChanged memetakan '
        'halaman 0 → selected null (= Semua, default provider) — sebelumnya '
        'null dipaksa ke dompet pertama sehingga total gabungan tak pernah '
        'tampil; 1 dompet tetap dikunci ke dompet itu. Onboarding: '
        'hasAnyTxProvider (AppDatabase.watchTxCount, COUNT(*) WHERE '
        'deleted_at IS NULL) → Beranda menyembunyikan PeriodSwitcher, '
        'FlowCards, kategori, dan riwayat, lalu menampilkan _OnboardingStart '
        '(CTA catat pengeluaran + scan struk). 2 test baru. 308 test.',
    breaking: null,
  ),
  (
    version: 'v1.37.1',
    date: '22 Okt 2026',
    user:
        'Penanda dompet di Beranda kini jelas: dompet yang sedang tampil '
        'ditandai pil panjang, bukan sekadar beda warna tipis. Tombol "Kelola '
        'dompet" pindah ke kanan supaya tidak tercampur dengan penanda '
        'halaman, dan pembaca layar (TalkBack) sekarang menyebut dompet mana '
        'yang sedang aktif.',
    tech:
        'v1.37.1: _Dot aktif = AnimatedContainer 18×6 (180ms), non-aktif 6×6 '
        'pakai scheme.outline (outlineVariant terukur 1,63:1 light / 2,13:1 '
        'dark — di bawah 3:1 WCAG 1.4.11); slot sentuh 48→28×32 (WCAG 2.2 AA '
        '24×24) agar pitch kembali 28px dan celah visual 22px; Semantics '
        'selected + inMutuallyExclusiveGroup + nama dompet; Kelola jadi '
        'trailing plain TextButton (ikon gear dibuang, home:manage di luar '
        'home:dots); haptic dobel dihapus (jumpToPage → onPageChanged → _pick '
        'sudah bergetar). 306 test.',
    breaking: null,
  ),
  (
    version: 'v1.37.0',
    date: '22 Okt 2026',
    user:
        'Beranda kini lebih fokus ke data: pilihan periode ada tepat di atas '
        'angka masuk/keluar, transaksi terakhir naik ke atas, dan menu '
        'dipangkas jadi empat pintasan yang belum ada di bilah bawah. Ketuk '
        'kartu Pemasukan/Pengeluaran untuk langsung membuka riwayat sesuai '
        'jenisnya, dan Kelola dompet kini tombol terpisah — tidak lagi jadi '
        'halaman tak sengaja saat menggeser kartu.',
    tech:
        'v1.37.0: urutan HomeScreen carousel → PeriodSwitcher/PeriodNav → '
        'FlowCards → recent → topcats → HomeFeatureGrid; tap FlowCards mengisi '
        'historyFilterProvider (HistoryFilter) lalu push HistoryScreen; '
        '_DailyStrip berlabel "Hari ini"; HomeFeatureGrid jadi StatelessWidget '
        '4 _LinkTile (Pindah dana/Budget/Laporan/Utang); AccountCarousel '
        'itemCount=list.length, dots hanya >1 (target sentuh 48/touchMin), '
        'home:manage TextButton di luar PageView + empty-state action. '
        '305 test.',
    breaking: null,
  ),
  (
    version: 'v1.36.2',
    date: '21 Okt 2026',
    user:
        'Sync keluarga kini hanya mengirim dompet yang kamu tandai Keluarga, '
        'jadi dompet pribadi tidak ikut. Saldo awal ikut tersinkron, transfer '
        'tidak bisa rusak satu sisi, budget yang dihapus bisa diurungkan, dan '
        'dompet arsip bisa dipulihkan.',
    tech:
        'pushableAccounts/pushableTx hanya isShared + accountUuid shared; '
        'pull menolak dompet pribadi baru dan transaksi non-shared '
        '(shouldPullAccount/pullableTx). accountToMap + RemoteAccount + '
        'upsertLocalAccount membawa openingBalance (nullable agar dokumen lama '
        'tidak menimpa angka lokal). Transfer: openTransaction mengarahkan '
        'transferId ke sheet ringkasan + hapus berpasangan; deleteTransfer '
        'jadi soft-delete tombstone agar hapus ikut sync; form catat tidak lagi '
        'membuka kaki transfer. upsertBudget mengosongkan deletedAt saat Undo. '
        'unarchiveAccount + archivedAccountsProvider + sheet Kelola. onCreate '
        'seed dompet Utama. Tanggal TransferSheet ikut activePeriodProvider. '
        'Copy privacy Keluarga + caption budget global diperjelas. '
        'firestore.rules mengizinkan openingBalance int.',
    breaking:
        'Jika memakai Sync keluarga, publish firestore.rules v1.36.2 lebih '
        'dulu lewat Firebase Console → Firestore → Rules. Tanpa itu, sync '
        'dompet akan ditolak karena field saldo awal baru.',
  ),
  (
    version: 'v1.36.1',
    date: '21 Okt 2026',
    user:
        'Mencatat saat sedang melihat kemarin atau bulan lalu kini memakai '
        'tanggal periode itu, jadi transaksi tidak tersimpan di luar layar. '
        'Laporan PDF ikut periode yang dipilih, aplikasi terkunci lagi saat '
        'ditinggal ke background, dan pintu ganda di Riwayat/Pengaturan '
        'dirapikan.',
    tech:
        'suggestedTransactionDate(period) di data/period.dart dipakai '
        'TxFormScreen (dulu selalu DateTime.now()). Export PDF: '
        'fetchPeriodReport + exportPeriodPdf/savePeriodPdfToFile (range '
        'Period, label per jenis, slug file); varian bulan tetap ada. '
        'app.dart: WidgetsBindingObserver + unlockedProvider=false saat '
        'paused, LockScreen jadi overlay DI ATAS Navigator supaya route '
        'yang di-push tidak menutupi kunci. Ikon kalender ganda di header '
        'Riwayat dihapus (chip Kalender satu-satunya pintu). Budget dapat '
        'caption "selalu per bulan". Grup Pengaturan jadi "Saldo, Privasi '
        '& Pengingat". 6 test baru (4 period + 1 PDF periode + 1 lock '
        'resume).',
    breaking: null,
  ),
  (
    version: 'v1.36.0',
    date: '21 Okt 2026',
    user:
        'Beranda dan Riwayat kini punya pilihan Harian, Mingguan, Bulanan, '
        'Tahunan, plus Kalender. Kalender menampilkan total masuk/keluar '
        'tiap tanggal — ketuk satu tanggal untuk melihat rincian harinya. '
        'Kartu Pemasukan/Pengeluaran ikut periode yang dipilih, dan tombol '
        '+ di bilah bawah tampil lebih besar.',
    tech:
        'Kalender: `ui/screens/calendar_screen.dart` + '
        '`calendarDailyTotalsProvider` (family per "yyyy-MM") + '
        '`AppDatabase.getDailyTotals` (agregasi lokal per hari, transfer '
        'dikecualikan). Chip Kalender ada di PeriodSwitcher (bukan '
        'PeriodKind — alat navigasi). Beranda/Riwayat: AppMonthNav diganti '
        'PeriodSwitcher + PeriodNav, historyProvider/historyCountProvider '
        'ikut periodRangeProvider, judul kategori pakai '
        'periodRelativeLabel. FlowCards pindah ke periodTotalsProvider + '
        'prevPeriodTotalsProvider dengan frasa delta per jenis periode. '
        'Shell: lingkaran + 64px (dari 56) menonjol 8px di atas kapsul; '
        'lingkaran pindah ke Stack luar karena Material kapsul meng-clip; '
        'token dockSlot 68→76, bottomPad 112→120. 5 test baru '
        '(calendar_test 4 + geometri FAB 1).',
    breaking: null,
  ),
  (
    version: 'v1.35.0',
    date: '21 Okt 2026',
    user:
        'Di Laporan kamu sekarang bisa memilih rentang waktu: Harian, '
        'Mingguan, Bulanan, atau Tahunan. Ringkasan dan rincian kategori '
        'langsung ikut rentang yang dipilih, dan perbandingan dihitung '
        'terhadap rentang sebelumnya yang setara.',
    tech:
        'Model baru `data/period.dart`: Period(kind, anchor) → range '
        '(start, endInclusive = endExclusive − 1ms, pola sama dengan '
        'monthRangeOf), pekan mulai SENIN, aritmetika lewat konstruktor '
        'DateTime(y,m,d±n) supaya bebas DST. Provider baru: '
        'periodKindProvider, periodAnchorProvider, activePeriodProvider '
        '(bulanan DITURUNKAN dari selectedMonthProvider → satu sumber '
        'kebenaran, layar bulanan tak bisa berbeda dari Laporan), '
        'periodTotalsProvider, prevPeriodTotalsProvider, '
        'periodExpenseByCategoryProvider. UI: PeriodSwitcher (ChoiceChip '
        'di ListView horizontal — SegmentedButton 4 label Indonesia '
        'overflow di textScaler 2.0) + PeriodNav (chevron + label + '
        'jalan pintas kembali), menggantikan AppMonthNav di Laporan. '
        'Grafik 6 bulan + strip wawasan tetap bulanan dan judulnya '
        'sekarang menyebut "(bulanan)" agar tidak salah konteks. '
        '13 test baru (period_test 12 + period_ui_test 4).',
    breaking: null,
  ),
  (
    version: 'v1.34.0',
    date: '21 Okt 2026',
    user:
        'Di Beranda kini ada dua kartu: Pemasukan dan Pengeluaran pada '
        'periode yang sedang kamu lihat, plus perbandingan dengan bulan '
        'sebelumnya. Ketuk salah satunya untuk langsung melihat daftar '
        'transaksinya.',
    tech:
        'Widget baru `ui/widgets/flow_cards.dart`: dua kartu terpisah di '
        'bawah carousel dompet (bukan diselipkan ke kartu saldo yang '
        'tinggi tetap 116px dan sudah overflow 70px di textScaler 2.0). '
        'Angka dari monthTotalsProvider + prevMonthTotalsProvider, delta '
        'persen (null-safe saat periode lalu 0 → "baru periode ini", '
        'tanpa Infinity/NaN). Menghormati displayPrefsProvider: Rp•••• '
        'saat privacy menyembunyikan semua nominal, dan teks delta ikut '
        'disamarkan supaya arah arus tidak bocor lewat persen. Nominal '
        'dibungkus FittedBox(scaleDown) + IntrinsicHeight agar dua kartu '
        'tetap sama tinggi tanpa overflow di font besar. Tap → Riwayat. '
        '5 test baru (flow_cards_test).',
    breaking: null,
  ),
  (
    version: 'v1.33.1',
    date: '21 Okt 2026',
    user:
        'Teks di dekat bilah bawah kini memudar halus sebelum menyentuh '
        'bilah (tidak lagi terpotong garis), ketukan Riwayat/Scan terasa '
        'balasannya, tulisan tetap rapi walau ukuran font HP diperbesar, '
        'dan bilah bawah menyingkir sebentar saat kamu menggulir.',
    tech:
        'Audit UI/UX overlay kapsul: scrim gradient setinggi bottomPad + '
        'safeBottom (transparan→surface, IgnorePointer) yang ikut tuck; '
        'kapsul jadi Material(color surface, shape, clip antiAlias) '
        'sehingga ripple InkWell kelihatan (dulu tertutup Container '
        'opaque di atas Material Scaffold); label maxLines 1 + ellipsis '
        '+ withClampedTextScaling 1.3; kapsul tuck AnimatedSlide 180ms '
        'saat scroll turun dan kembali saat ScrollEnd atau arah '
        'berbalik (baseline reset di ScrollStart); lingkaran + pindah ke '
        'Material(primary)+InkWell (satu-satunya kontrol tanpa ripple); '
        'spacer tengah ikut men-tap Catat (hapus zona mati ±10px). '
        'Slot: kapsul kembali ke bottomNavigationBar + extendBody true '
        '(bukan floatingActionButton) — body tetap penuh 844, margin 12, '
        'dan SnackBar/keyboard/safe-area/semantik kembali urusan '
        'Scaffold. 4 test baru. Radius 16 & susunan Riwayat/+/Scan '
        'sengaja tidak diubah (bentuk v1.33.0).',
    breaking: null,
  ),
  (
    version: 'v1.33.0',
    date: '21 Okt 2026',
    user:
        'Bilah bawah kini benar-benar melayang di atas layar — konten '
        'tergulir di belakangnya, dan posisinya tetap rapi di HP dengan '
        'navigasi gestur.',
    tech:
        'Shell: kapsul 232×56 yang sama dipindah dari bottomNavigationBar '
        'ke slot floatingActionButton + centerFloat. Viewport body naik '
        '776→844 (konten lewat di belakang kapsul); jarak bawah 12 → '
        'kFloatingActionButtonMargin 16 + SafeArea dalam slot. Token '
        'clearance/bottomPad 112 tak berubah; key home:navbar '
        'dipertahankan → regression shell lama tetap berlaku.',
    breaking: null,
  ),
  (
    version: 'v1.32.6',
    date: '14 Okt 2026',
    user:
        'Konten paling bawah kini bisa digulir sampai terlihat sepenuhnya '
        'di atas bilah bawah — termasuk di HP dengan navigasi gestur.',
    tech:
        'Clearance adaptif: ekor Beranda = bottomPad + safeBottom aktual '
        '(rumus dockSlot 68 + safe + breath 44); token dockSlot/dockBreath '
        'baru; 9 layar lain tetap statis. Regression test clearance.',
    breaking: null,
  ),
  (
    version: 'v1.32.5',
    date: '14 Okt 2026',
    user:
        'Bayangan bilah bawah kini lebih ramping dan proporsional — '
        'teks di layar tetap jernih dibaca di sekitar bilah bawah.',
    tech:
        'Token scoped AppShadows.dock() (blur 20/offset 4 ganti '
        'floating() blur 32/offset 12 khusus kapsul 56); viewport '
        'berhenti pas di tepi dock; bottomPad tetap 112. Regression '
        'test keterbacaan bayangan.',
    breaking: null,
  ),
  (
    version: 'v1.32.4',
    date: '14 Okt 2026',
    user:
        'Tombol + di bilah bawah kini duduk rapi di dalam kapsul — teks '
        'di layar (nama kategori, persen, nominal) tidak lagi tertutup '
        'saat digulir.',
    tech:
        'Shell: lingkaran 72 top -16 (kepala 15px + glow di atas kapsul, '
        '5 hits probe) → 56 flush top 0 dalam kapsul; extendBody false; '
        'bottomPad 96→112. Regression test dock.',
    breaking: null,
  ),
  (
    version: 'v1.32.3',
    date: '14 Okt 2026',
    user:
        'Tombol mata di kartu saldo kini berfungsi normal: ketuk untuk '
        'sembunyikan/tampilkan saldo tanpa membuka halaman lain, dan '
        'posisinya rapi di pojok kanan kartu.',
    tech:
        'Carousel: mata toggle keluar dari subtree Listener kartu jadi '
        'sibling di Stack selebar kartu (posisi pojok kanan tetap saat '
        'saldo sempit; tap tak fire ganda toggle+detail). 2 regression '
        'test (toggle-only + posisi Rp0).',
    breaking: null,
  ),
  (
    version: 'v1.32.2',
    date: '14 Okt 2026',
    user:
        'Perbaiki layar Beranda yang sempat kosong: konten kini tampil lagi, '
        'bilah bawah tetap ramping di tengah.',
    tech:
        'Shell: Center → Row-centered di bottomNavigationBar (Center '
        'mengembang penuhi slot vertikal → body 0px, probe: dock tengah + '
        'body kosong); Row hanya bungkus horizontal. Test rect: body ada + '
        'dock 232 centered di bawah.',
    breaking: null,
  ),
  (
    version: 'v1.32.1',
    date: '14 Okt 2026',
    user:
        'Bilah bawah kini ramping dan-centered: tidak lagi selebar layar, '
        'tombol + tetap besar menonjol di tengah.',
    tech:
        'Shell: full-width 358px → dock kompak 232×56 centered (Center + '
        'width 232); tinggi 48→56 agar lingkaran 72 overlap -16 flush; '
        'spacer tengah pensiun; test rect lebar + tinggi.',
    breaking: null,
  ),
  (
    version: 'v1.32.0',
    date: '14 Okt 2026',
    user:
        'Bilah bawah dibuat lebih ramping (tombol + tetap besar). Tombol '
        'catat di rincian dompet kini melayang agar selalu terlihat. Rincian '
        'dompet kini punya pengaturan sendiri: ganti nama, saldo awal, '
        'arsip, dan tombol atur dompet ini dikelola keluarga atau tetap '
        'pribadi.',
    tech:
        'Shell: bar 60→48 (batas touchMin, overlap -16 tetap) + test rect. '
        'Detail: SettingRow Catat → FAB (detail:fab) buka form scoped. '
        'Seksi Pengaturan per-dompet: rename + openingBalance + arsip + '
        'Switch isShared (skema v5, migrasi addColumn default false, sync '
        'LWW via RemoteAccount/accountToMap/upsertLocalAccount). Test: '
        'FAB→form Catat ke, seksi pengaturan, toggle persist + sync map.',
    breaking: null,
  ),
  (
    version: 'v1.31.0',
    date: '14 Okt 2026',
    user:
        'Kartu riwayat kini bersih tanpa panah — seluruh baris tetap bisa '
        'diketuk untuk ubah. Daftar Riwayat diberi jarak lega seperti '
        'Beranda. Kartu saldo fokus ke angka saja (tombol catat pindah ke '
        'tombol + dan menu). Ketuk kartu saldo untuk buka rincian dompet: '
        'riwayat, budget, utang, pindah dana, laporan, dan pengaturan. '
        'Form catat kini jelas menulis ke dompet mana. Tombol + bawah '
        'diperbesar, bilah navigasi dibuat lebih ramping.',
    tech:
        'TxTile: chevron_right dihapus (tap → edit tetap via InkWell). '
        'HistoryScreen: Padding top s8 antar kartu (pola _RecentList). '
        'AccountCarousel: CTA + Catat keluar & Buka kelola dihapus, '
        'viewport 264→188, tap kartu via Listener mentah (_TapToOpen, '
        'tanpa gesture arena agar drag PageView bebas). Layar baru '
        'AccountDetailScreen (hero mesh + 5 tx scoped + 8 pintasan, '
        'override selectedAccountProvider). TxFormScreen: param '
        'initialAccountId + field Catat ke + sheet pilih dompet. Shell: '
        'bar 72→60, tombol 64→72 + ikon 28→32. Test: drag presisi → '
        'fling -200/-350 1000 (snap-balik sejak kartu 188px).',
    breaking: null,
  ),
  (
    version: 'v1.30.1',
    date: '14 Okt 2026',
    user:
        'Daftar "Terakhir dicatat" kini lebih lega dibaca — tiap kartu '
        'diberi jarak. Bentuk kartu dan gambar ikon di seluruh aplikasi '
        'dibuat lebih ramping agar tidak terlalu membulat. Tombol kembali '
        'di semua halaman kini tampil polos tanpa kotak.',
    tech:
        'RecentList Padding s8 antar-TxTile + test rect >=8px; token card '
        '24→16 + thumb 16→12; BackHeader + AppHeader.onBack bordered:false '
        '(aksi form scan/hapus tetap kotak); golden regen.',
    breaking: null,
  ),
  (
    version: 'v1.30.0',
    date: '14 Okt 2026',
    user:
        'Kartu Kelola dompet kini sejajar dengan kartu saldo — tidak '
        'melompat lagi saat digeser, dan titik halaman ikut sampai kartu '
        'terakhir. Tiap transaksi dan judul kini menyebut nama dompetnya '
        'bila Anda punya lebih dari satu. Tombol dan kartu di seluruh '
        'aplikasi tampil lebih membulat dan lembut.',
    tech:
        'Kartu Kelola parity bingkai + dots halaman list.length+1 + '
        'guard sync-back _prevIndex; watchHistory JOIN accounts + suffix '
        'multi-dompet (>1) di Beranda/Riwayat/Laporan; token pill/kartu/'
        'thumb + MeshGradient ringkasan utang; kontras mesh utang >=4.5:1 '
        '(96 pengukuran); golden regen.',
    breaking: null,
  ),
  (
    version: 'v1.29.1',
    date: '14 Okt 2026',
    user:
        'Tombol Beranda di bawah kini jadi pintasan Riwayat. '
        'Kelola dompet pindah ke kartu bergambar gear di ujung kartu saldo. '
        'Lingkaran + tengah diperbaiki agar tampil utuh di semua HP.',
    tech:
        'Shell [Riwayat][+][Scan]; kartu Kelola trailing; navbar Stack+SafeArea; '
        'drag presisi −350; 19 regression test.',
    breaking: null,
  ),
  (
    version: 'v1.29.0',
    date: '13 Okt 2026',
    user:
        'Tiap dompet kini punya kartu saldonya sendiri di Beranda — '
        'geser untuk pindah dompet. Urutan kartu bisa diatur dari '
        'Kelola dompet.',
    tech:
        'Carousel PageView ganti hero+chip; reorder sortOrder (+sync); '
        '9 regression test carousel+reorder.',
    breaking: null,
  ),
  (
    version: 'v1.28.0',
    date: '13 Okt 2026',
    user:
        'Tampilan baru yang lebih hidup: kartu saldo kini bergradasi cair '
        'mengikuti warna pilihanmu, tombol dan menu berbentuk kapsul yang '
        'ramah, dan bilah bawah tampak melayang. Semua teks tetap jelas '
        'dibaca di semua warna.',
    tech:
        'Identitas visual v1.28: MeshGradient hero + overview status '
        '(hue-shift, putih >=4.5:1 terukur 6 aksen x 2 tema), AppShadows '
        'lembut (tanpa hitam pekat), radius pill/kartu/thumb, bottom bar '
        'melayang + tombol glow, gradient literal dilarang; '
        'docs/08-Karakteristik-Tampilan.md + 4 test visual_identity; '
        'golden regen; full 236/236.',
    breaking: null,
  ),
  (
    version: 'v1.27.1',
    date: '13 Okt 2026',
    user:
        'Perbaiki: tombol Masuk kini tampil di Beranda sebelum login — '
        'ketuk untuk buka halaman Profil lalu masuk Google. Sebelumnya '
        'jalan login tidak terlihat sama sekali saat belum masuk.',
    tech:
        'Tombol teks Masuk di header personal → Profil (opsi B); '
        '2 assertion regression test.',
    breaking: null,
  ),
  (
    version: 'v1.27.0',
    date: '13 Okt 2026',
    user:
        'Beranda kini menyapa Anda setelah masuk Google — ketuk foto/nama '
        'untuk buka halaman Profil (nama panggilan bisa diubah, Keluarga '
        'pindah ke sana). Pengaturan jadi 4 grup.',
    tech:
        'Pohon akun Beranda → Profil → Keluarga; header kondisional login; '
        'nickname lokal prefs; grup Keluarga hapus dari hub; '
        '5 regression test.',
    breaking: null,
  ),
  (
    version: 'v1.26.0',
    date: '12 Okt 2026',
    user:
        'Beranda kini punya menu cepat: catat masuk/keluar, pindah dana, '
        'dan scan struk dalam satu layar; navigasi bawah ramping jadi '
        'Beranda, Catat, dan Scan.',
    tech:
        'Grid menu 4x2 (aksi + lihat) + nav 3 tombol + alur scan '
        'kamera/galeri → pratinjau → simpan; 10 regression test.',
    breaking: null,
  ),
  (
    version: 'v1.25.1',
    date: '12 Okt 2026',
    user:
        'Perbaiki: kolom nama dompet tidak lagi hilang saat keyboard '
        'muncul — panel tambah, ganti-nama, dan pindah dana kini ikut '
        'naik di atas keyboard.',
    tech:
        '3 sheet dompet keyboard-safe (isScrollControlled + viewInsets); '
        '2 regression test keyboard.',
    breaking: null,
  ),
  (
    version: 'v1.25.0',
    date: '12 Okt 2026',
    user:
        'Kini bisa punya banyak dompet (mis. Pribadi + Keluarga): pilih '
        'di Beranda, pindah dana antar dompet, dan saring Riwayat, '
        'Laporan, Utang, dan Budget per dompet. Data lama otomatis masuk '
        'dompet "Utama" — saldo tidak berubah.',
    tech:
        'Skema v4: tabel Accounts + accountId/accountUuid/transferId; '
        'backfill seed Utama; agregat + 8 provider sadar-dompet; '
        'transfer 2 kaki netral (filter transfer_id); koleksi sync '
        'accounts + rules; AccountPicker + Kelola + TransferSheet; '
        'filter sheet Riwayat + PDF sadar-dompet; 25 test dompet; '
        '215/215 hijau.',
    breaking: null,
  ),
  (
    version: 'v1.24.11',
    date: '12 Okt 2026',
    user:
        'Halaman Laporan kini menjawab: selisih ditonjolkan, grafik '
        'punya keterangan warna, ada kalimat wawasan vs bulan lalu, '
        'dan diagram lingkaran menyebut nama kategorinya.',
    tech:
        'Selisih hero 20px + judul dinamis; sixMonthFlow/prevMonth '
        'provider (ganti FutureBuilder); legenda bar+pie + Semantics; '
        'privacy rata-batang; iris <=3% bisu + footnote 6-terbesar; '
        '8 test Laporan; vision light+dark PASS.',
    breaking: null,
  ),
  (
    version: 'v1.24.10',
    date: '12 Okt 2026',
    user:
        'Baris Riwayat kini dua lapis (catatan di atas, kategori + '
        'nominal di bawah) dan filter pindah ke panel bawah dengan '
        'tombol + badge jumlah aktif.',
    tech:
        'TxTile Column 2-baris (nominal tetap Expanded rata kanan); '
        'chip scroll → _FilterButton + _FilterSheet (Tipe + Kategori + '
        'Reset + Terapkan); 6 test sheet; golden Beranda regen.',
    breaking: null,
  ),
  (
    version: 'v1.24.9',
    date: '11 Okt 2026',
    user:
        'Pencarian Riwayat kini menemukan nama kategori dan nominal, '
        'angka total jujur saat data banyak, dan pesan kosong yang '
        'tidak lagi menuduh.',
    tech:
        'Search note+kategori+nominal; watchHistoryCount + strip '
        '"Menampilkan X dari N"; Semua sadar keyword + toggle tipe; '
        'debounce 300ms; empty bercabang; chip Semantics + minHeight 48 '
        '+ ellipsis; TxTile dense arsip; hint scope bulan; 7 test baru, '
        'golden identik.',
    breaking: null,
  ),
  (
    version: 'v1.24.8',
    date: '11 Okt 2026',
    user:
        'Tombol header kini polos tanpa kotak, dan halaman Riwayat '
        'menjawab: ada total hasil, tanggal dikelompokkan, tombol '
        '"Semua" beneran menampilkan semua.',
    tech:
        'AppIconButton bordered:false (gear/chevron/mata, hit-area '
        'tetap 48px); Riwayat: Semua reset kategori, strip hasil '
        'count+masuk+keluar, grup tanggal DESC + showDate false, '
        'picker kunci bulan berjalan + helpText jujur; 4 regression '
        'test baru, golden diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.7',
    date: '11 Okt 2026',
    user:
        'Tampilan makin konsisten di semua halaman: jarak, tombol, '
        'dan header kini satu bahasa desain.',
    tech:
        'Unifikasi global: BackHeader + slot aksi (tombol 48px + '
        'haptic), tokenize ±60 literal padding/radius/gap lintas 14 '
        'file, token micro optik, golden identik nol piksel berubah.',
    breaking: null,
  ),
  (
    version: 'v1.24.6',
    date: '11 Okt 2026',
    user:
        'Bagian atas Beranda kini ada nama aplikasi di kiri dan tombol '
        'pengaturan di kanan, sejajar rapi.',
    tech:
        'Beranda: header yatim 1 gear → AppHeader shared (wordmark + '
        'gear, pola Riwayat), regression test header, golden '
        'diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.5',
    date: '11 Okt 2026',
    user:
        'Angka transaksi kini rata kanan sejajar, dan ringkasan hari '
        'ini tampil lebih ringkas.',
    tech:
        'Tile: kolom nominal Expanded + chevron jangkar, grup tanggal '
        'sort eksplisit, strip satu baris, 2 regression test, golden '
        'diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.4',
    date: '11 Okt 2026',
    user:
        'Daftar transaksi makin rapi: tanggal tidak diulang di tiap '
        'baris, plus logo baru aplikasi.',
    tech:
        'Tile: showDate per konteks, subtitle tanpa duplikat, header '
        'grup naik gaya, Riwayat token rapi, logo bg-white (in-app + '
        'launcher 5 densitas), golden diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.3',
    date: '11 Okt 2026',
    user:
        'Beranda makin jelas: tombol utama lebih menonjol, tulisan '
        'link lebih spesifik, dan tampilan bulan selaras dengan kartu.',
    tech:
        'Beranda: token tinggi tombol, teks tombol 17px, trailing '
        'konteks, monthnav ikut token border, microcopy jujur, golden '
        'diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.2',
    date: '11 Okt 2026',
    user:
        'Beranda makin rapi: jarak antar bagian lebih lega, kartu lebih '
        'jelas di mode gelap, dan tombol mata lebih mudah disentuh.',
    tech:
        'Beranda: token spacing/tipe/border baru, header ramping, status '
        'bar adaptif tema, saldo anti-kepotong, golden diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.1',
    date: '11 Okt 2026',
    user:
        'Perbaikan tampilan: tombol catat di Beranda kini jelas terbaca '
        'di mode gelap.',
    tech:
        'Hero Beranda: foreground tombol ikut warna tema (bukan putih '
        'tetap), tambah test kontras tombol 6 aksen x 2 tema, golden '
        'diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.24.0',
    date: '11 Okt 2026',
    user:
        'Beranda B2C minimalis: kartu putih bersih dengan saldo besar + 1 tombol catat. '
        'Sapaan, delta insight, catat kilat, dan budget dihapus untuk tampilan lebih simple.',
    tech:
        'HomeScreen: header strip netral (cuma gear), hero kartu border (48px saldo + CTA solid), '
        'slot delta/kilat/debts dihapus, spacing 32px, stagger entrance dihapus (510 baris, dari 1517). '
        'Test: 11/11 hijau (kontras skip, hero/budget/kilat kontrak diupdate v1.24).',
    breaking: null,
  ),
  (
    version: 'v1.23.0',
    date: '11 Okt 2026',
    user:
        'Beranda kini simple tanpa kartu streak — bersih dan minimalis. '
        'Saldo, budget, dan semua fitur lain tetap sama.',
    tech:
        'Hapus _StreakCard + _streakProvider/_calcStreak + slot home:streak, '
        'rapikan stagger 1-5, test streak jadi absence-test, golden '
        'diregenerasi.',
    breaking: null,
  ),
  (
    version: 'v1.22.0',
    date: '11 Okt 2026',
    user:
        'Beranda tampil beda total: saldo besar di atas, ringkasan masuk-'
        'keluar-budget dalam satu panel, insight bulan lalu jadi strip '
        'ringkas, plus logo baru di aplikasi.',
    tech:
        'home_screen.dart redesign: header strip ramping, hero ledger full-'
        'bleed (saldo 40px + kolom Masuk/Keluar + ledger budget + tombol 2 '
        'kolom), _DeltaStrip ganti banner ganda, hapus _StatTiles/_megaButton/'
        '_incomeLink/_bannerBox/_bannerCta/_tile/_darkBanner, golden '
        'diregenerasi, logo app_logo.png + mipmap diganti redesigned.',
    breaking: null,
  ),
  (
    version: 'v1.21.1',
    date: '10 Okt 2026',
    user:
        'Audit referensi Beranda: semua tombol kini bergetar ringan saat '
        'disentuh (termasuk tombol di banner dan kartu utang). Isi dan '
        'datamu tidak berubah.',
    tech:
        'Tambah haptic CTA banner + kartu utang Beranda (prompt referensi '
        'satu-file); pola hardcode + TODO + FAB + emoji PDF ditolak — '
        'provider live + ikon vektor + tema dipertahankan, full 163/163.',
    breaking: null,
  ),
  (
    version: 'v1.21.0',
    date: '10 Okt 2026',
    user:
        'Beranda kini terasa seperti papan kemenangan: saldo menghitung '
        'naik saat dibuka, sisa budget bulan ini langsung kelihatan di '
        'kartu utama, ada streak harian biar rajin catat, plus Catat Kilat '
        '— ketuk nominal langsung kebuka form yang sudah terisi. Datamu '
        'tidak berubah, cuma Berandanya yang makin semangat.',
    tech:
        'Hero count-up + pacing budget dihitung di awal + tombol raksasa '
        '56px + streak N hari + dots 7 + misi harian (hitung Dart murni, '
        'tanpa skema) + TxFormScreen.initialAmount (backward-compatible) + '
        'fix FittedBox tile + ikon api vektor + chip kartu-terang, 3 test '
        'baru, full 163/163.',
    breaking: null,
  ),
  (
    version: 'v1.20.0',
    date: '10 Okt 2026',
    user:
        'Tampilan kini terasa hidup di semua halaman: kartu terangkat '
        'lembut, layar kosong punya ilustrasi medali, daftar muncul '
        'berurutan halus, tombol bergetar ringan saat disentuh, dan pindah '
        'halaman mengalir mulus. Isi dan datamu tidak berubah — cuma '
        'tampilannya yang naik kelas.',
    tech:
        'Token gerak AppMotion (durasi+kurva satu sumber) + Stagger '
        'entrance tanpa timer (TweenAnimationBuilder+Interval, aman '
        'fake_async) + progress animasi + empty-state medali gradien + '
        'AppCard shadow 5% + haptic global (TxTile/SettingRow/AppIconButton/'
        'pil hero/segmented/export/Kunci) + hero shine + stagger semua '
        'halaman + transisi fade-through, full 160/160.',
    breaking: null,
  ),
  (
    version: 'v1.19.1',
    date: '10 Okt 2026',
    user:
        'Anggota rumah kini bisa diketik untuk dikelola: naik/turun peran, '
        'keluarkan anggota, keluar rumah — semua pakai konfirmasi. '
        'Tombol Keluar utama juga kini tanya dulu + beri peringatan bila '
        'kamu pengelola satu-satunya.',
    tech:
        'CRUD anggota: canRemoveMember guard murni + setMemberRole + '
        'removeMember + rules delete owner-bisa-kick + bottom sheet kelola '
        '+ dialog konfirmasi keluar (offline ditolak ramah), test guard '
        '3 kasus, full 160/160.',
    breaking: null,
  ),
  (
    version: 'v1.19.0',
    date: '10 Okt 2026',
    user:
        'Keluarga sekarang bisa saling nyatat (beta): tap Sync data di '
        'Keluarga untuk kirim + ambil transaksi dan kategori serumah. '
        'Hapus kini merambat ke pasangan — utang tetap lokal dulu.',
    tech:
        'Sync engine beta: sync_engine murni (LWW updatedAt, categoryUuid '
        'resolve, skip cermin utang) + sync_service push/pull cats+tx + '
        'soft-delete actions + rules cats/tx anggota-only + UI status, '
        'test sync_engine 9 kasus, full 157/157.',
    breaking: null,
  ),
  (
    version: 'v1.18.1',
    date: '10 Okt 2026',
    user:
        'Pesan error Keluarga sekarang jujur: WiFi nyala tapi internet lemot '
        '(kasus 0,76 KB/S) dibilang "sinyal lemot — pindah jaringan", bukan '
        '"tidak ada internet". Tombol bicara "tanpa sinyal" saat radio mati.',
    tech:
        'Audit screenshot ReWin: pisah timeout/deadline/aborted (sinyal lemot) '
        'dari network/unavailable (tanpa internet), copy UI preemptif jujur '
        '"tanpa sinyal", test +1, full 148/148.',
    breaking: null,
  ),
  (
    version: 'v1.18.0',
    date: '10 Okt 2026',
    user:
        'Halaman Keluarga naik kelas: tombol mati sendiri saat offline (bukan '
        'gagal sesudah ditekan), nama dibatasi 40 huruf, daftar anggota tampil, '
        'kode bisa dibagikan ke WA, dan sapaan Beranda ikut waktu (Selamat '
        'pagi/siang/sore/malam) + nama akunmu.',
    tech:
        'Production-grade Keluarga+sapaan: isOfflineProvider (connectivity_plus) '
        'disable preemptif Buat/Gabung/Salin/Putar, validateHouseholdName max 40 + '
        'counter live, fetchMembers + isOwner guard, SharePlus invite + fallback '
        'salin, greeting.dart murni (title/resolve/text) + copy Baru, test +4, '
        'full 147/147.',
    breaking: null,
  ),
  (
    version: 'v1.17.4',
    date: '10 Okt 2026',
    user:
        'Login Google tidak lagi macet di "Menghubungkan...": tiap langkah '
        'dibatasi waktunya, kalau jaringan lemot muncul pesan jelas + tombol '
        'Coba lagi. Gabung pakai kode juga diperbaiki.',
    tech:
        'Audit login: timeout berlapis signIn (Google 60 dtk, Firebase 45 '
        'dtk, store 20 dtk) + fallback signedIn, fix join baca nama dari '
        'dokumen invite (bukan households), householdName di invite '
        'buat/putar, pesan permission-denied jujur. Full 131/131.',
    breaking: null,
  ),
  (
    version: 'v1.17.3',
    date: '10 Okt 2026',
    user:
        'Perbaiki halaman Keluarga yang macet di loading: kalau pemeriksaan '
        'otomatis tersendat, halaman tetap tampil dalam 8 detik dan tombol '
        'masuk tetap bisa ditekan manual.',
    tech:
        'Fix hang boot Keluarga: timeout 8 detik untuk silent-login + baca '
        'server (CredentialManager nyangkut = future menggantung), fallback '
        'signedIn/personal. Test regresi bootTimeout. Full 128/128.',
    breaking: null,
  ),
  (
    version: 'v1.17.2',
    date: '10 Okt 2026',
    user:
        'Login Google di halaman Keluarga sekarang bisa dicoba lagi: '
        'konfigurasi server sudah dilengkapi. Butuh internet sekali saat '
        'login; tanpa login aplikasi tetap offline seperti biasa.',
    tech:
        'Config-only tanpa perubahan kode: google-services.json baru '
        '(3 oauth client termasuk web), secret CI diperbarui. Full 127/127.',
    breaking: null,
  ),
  (
    version: 'v1.17.1',
    date: '10 Okt 2026',
    user:
        'Halaman Keluarga dirapikan: ada penjelasan manfaat + tombol masuk '
        'yang besar, dan kalau login gagal pesannya jelas (ada tombol Coba '
        'lagi), bukan tulisan samar di bawah.',
    tech:
        'UX Keluarga: hero empty-state + error card inline (kontras tinggi, '
        'ada retry), perluas friendlyAuthError (config v7, provider '
        'nonaktif), AuthService null-safe tanpa Firebase init, '
        'family_ux_test. Full 127/127.',
    breaking: null,
  ),
  (
    version: 'v1.17.0',
    date: '10 Okt 2026',
    user:
        'Baru: menu Keluarga di Pengaturan. Masuk dengan akun Google untuk '
        'membuat rumah tangga dan mengundang pasangan pakai kode (atau '
        'gabung pakai kode dari pasangan). Tanpa login, aplikasi tetap '
        '100% offline seperti biasa.',
    tech:
        'Keluarga Fase 1 (opt-in): google_sign_in v7 → Firebase Auth + '
        'Firestore mywallet-7614d, household.dart murni (invite 8 char, '
        'TTL 24 jam), auth_service + layar Keluarga, firestore.rules '
        'anggota-only (koleksi sync tx/cats ditolak sampai Fase 2).',
    breaking: null,
  ),
  (
    version: 'v1.16.2',
    date: '10 Okt 2026',
    user:
        'Perbaikan penting buat yang pakai backup: pulihkan backup, hapus '
        'semua data, dan pindah dari aplikasi lama sekarang anti-gagal '
        '(sebelumnya bisa macet dengan pesan error koneksi database).',
    tech:
        'Lokasi file DB dihitung langsung tanpa query (aman setelah koneksi '
        'ditutup), WAL checkpoint sebelum backup, validasi header SQLite '
        'sebelum timpa (file sampah ditolak, data aman). Restore '
        'antar-package v1.16.0 → v1.16.1+ bisa jalan.',
    breaking: null,
  ),
  (
    version: 'v1.16.1',
    date: '10 Okt 2026',
    user:
        'Persiapan pindah ke aplikasi resmi + fondasi login Google dan '
        'sinkronisasi antar-HP di update berikutnya (belum aktif — aplikasi '
        'tetap 100% offline, datamu tidak dikirim ke mana pun).',
    tech:
        'Ganti package Android ke com.rezal.mywallet + wiring Firebase Fase 1 '
        '(project mywallet-7614d): plugin google-services 4.5.0, firebase_core '
        'init aman-gagal (tanpa config = tetap offline murni), paket '
        'firebase_auth + cloud_firestore + google_sign_in v7, minSdk 23. '
        'google-services.json di-gitignore + CI via secret.',
    breaking:
        'Update ini terinstall sebagai aplikasi BARU (data mulai dari nol) — '
        'backup dulu via Kelola sebelum update.',
  ),
  (
    version: 'v1.16.0',
    date: '10 Okt 2026',
    user:
        'Tidak ada yang berubah di tampilan — ini fondasi di balik layar '
        'agar datamu nanti bisa sinkron antar-HP (misalnya HP pribadi dan HP '
        'bersama pasangan). Datamu tetap 100% tersimpan di HP.',
    tech:
        'Fondasi sync-ready Fase 0 (tetap 100% offline, tanpa network): skema '
        'DB v3 — semua tabel punya uuid (identitas antar-HP), updatedAt '
        '(jejak tulis), deletedAt (soft-delete), householdId (pribadi vs rumah '
        'tangga) + categoryUuid di transaksi. Migrasi v2→v3 aman (data lama '
        'utuh, backfill otomatis). Semua query (saldo/laporan/riwayat/budget/'
        'utang) siap soft-delete. Persiapan Google Sign-In + Firestore '
        '(Fase 1-2).',
    breaking: null,
  ),
  (
    version: 'v1.15.0',
    date: '9 Okt 2026',
    user:
        'Baru: tab Utang. Catat utang dan piutang, bayar/terima cicilan '
        'berkali-kali dengan pengingat jatuh tempo, otomatis lunas saat sudah '
        'pas. Semua ikut tercatat di saldo dan laporan seperti biasa.',
    tech:
        'Manajer utang-piutang (100% offline): tab Utang ke-5 + kartu ringkas '
        'di Beranda (sisa utang vs piutang, tap → Kelola). Utang = pinjam '
        '(catat = pemasukan, bayar = pengeluaran), Piutang = meminjami '
        '(catat = pengeluaran, terima = pemasukan) — tiap aksi menulis '
        'transaksi cermin otomatis sehingga saldo, laporan, riwayat, PDF & '
        'CSV ikut tanpa ubah query lama. Cicilan parsial berkali-kali + '
        'anti-overpay + jatuh tempo + progress + lunas otomatis. Skema DB v2 '
        '(migrasi v1→v2 aman, data lama utuh).',
    breaking: null,
  ),
  (
    version: 'v1.14.0',
    date: '8 Okt 2026',
    user:
        'Baru: kirim laporan bulanan sebagai file PDF (bisa dibagikan via '
        'WA), dan catat belanja cukup dengan memfoto struk — nominal, tanggal, '
        'dan nama warung terisi otomatis, kamu tinggal cek lalu simpan.',
    tech:
        'Export PDF laporan + Scan struk (100% offline): tombol PDF di Laporan '
        '& Kelola (ringkasan Masuk/Keluar/Selisih + rincian kategori % + '
        'daftar transaksi, via share sheet / simpan file, tanpa server/'
        'API-key); tombol scan di form Catat (kamera/galeri → ML Kit on-device '
        '→ prefill nominal + tanggal + warung + saran kategori, user tetap cek '
        '& Simpan manual). Izin kamera baru. Logika simpan/transaksi tidak '
        'berubah.',
    breaking: 'Butuh izin kamera baru saat pertama pakai scan struk.',
  ),
  (
    version: 'v1.13.1',
    date: '8 Okt 2026',
    user:
        'Tampilan Beranda baru: sapaan personal dengan namamu, kartu saldo '
        'warna-warni mengikuti warna tema pilihanmu di Pengaturan.',
    tech:
        'Samakan Beranda dengan mockup ala GoPay: sapaan personal '
        '“Hai, {nama}” (baru di Pengaturan → Tampilan → Nama sapaan, default '
        'Nievi) dengan ikon mahkota, tanggal panjang, label saldo, nav bulan '
        'hanya saat menjelajah bulan lain, aksi cepat 4 chip, tile metrik '
        'Masuk/Keluar/SISA BUDGET, ringkasan “Hari ini” pindah ke seksi '
        'Terakhir dicatat. Warna dijenuhkan (+35%); kontras putih ≥4.5:1. '
        'Logika/provider/query tidak berubah.',
    breaking: null,
  ),
  (
    version: 'v1.13.0',
    date: '8 Okt 2026',
    user:
        'Beranda pola baru: kepala sapaan berwarna, kartu saldo gradien, '
        'jalan pintas, info perbandingan bulan lalu, dan status budget sekilas.',
    tech:
        'Beranda pola GoPay: kepala sapaan berwarna aksen + kartu saldo '
        'gradien ikut warna tema (kontras putih ≥4.5:1, 48 pengukuran 6 aksen '
        '× 2 tema), aksi cepat Catat/Riwayat/Budget/Laporan, banner insight '
        '(delta vs bulan lalu + pacing budget + CTA), tile metrik '
        'Masuk/Keluar/Hari ini. Logika/provider/query tidak berubah.',
    breaking: null,
  ),
  (
    version: 'v1.12.1',
    date: '8 Okt 2026',
    user:
        'Beranda makin rapi dan cepat: angka pemasukan/pengeluaran konsisten '
        'di semua layar, tombol atur budget muncul saat dibutuhkan.',
    tech:
        'Polish Beranda: semantik nominal satu sumber (AppColors '
        'income/expense + varian hero), delta % via provider (tanpa query '
        'ulang tiap rebuild), CTA "Atur budget" saat kosong, strip hari ini '
        'jelas saat nol, hero berboder di dark mode, golden test + uji kontras '
        'WCAG 4.5:1. README baru ala landing page.',
    breaking: null,
  ),
  (
    version: 'v1.12.0',
    date: '8 Okt 2026',
    user:
        'Beranda kini menjawab “bulan ini aman nggak?” sekilas: arus kas, '
        'perbandingan dengan bulan lalu, dan status budget — plus navigasi '
        'bawah baru yang lebih rapi.',
    tech:
        'Beranda menjawab "bulan ini aman nggak?": header sapaan pinned (gear '
        'tidak hilang), hero netral + arus semantik + delta vs bulan lalu + '
        'pacing budget, kategori proporsional + persen, riwayat tergrup '
        'tanggal + chevron, navigasi M3 NavigationBar, skeleton shimmer + '
        'error ramah di semua layar.',
    breaking: null,
  ),
  (
    version: 'v1.11.0',
    date: '8 Okt 2026',
    user:
        'Logo baru + pengalaman catat lebih mulus: tombol + melebar jadi form, '
        'nominal terisi otomatis saat diketik, ada getaran halus di tiap sentuhan.',
    tech:
        'Logo MyWallet + Micro-UX premium: FAB Container Transform '
        '(OpenContainer) jadi form Catat, nominal autofocus + quick-add chips, '
        'haptic di FAB/kategori/simpan, empty state memotivasi, nama aplikasi '
        'MyWallet.',
    breaking: null,
  ),
  (
    version: 'v1.10.2',
    date: '8 Okt 2026',
    user: 'Perbaikan tampilan bar bawah (blok hitam belang hilang).',
    tech:
        'Fix bar bawah: blok hitam belang hilang + notch FAB rapat (extendBody '
        '+ buang SafeArea pembungkus, visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.10.1',
    date: '8 Okt 2026',
    user: 'Tombol + Catat menyatu rapi di bar bawah, ikon seragam di semua layar.',
    tech:
        'Penyeragaman: FAB Catat tertanam via BottomAppBar notch + Beranda '
        'CustomScrollView satu-sliver-per-section + ikon monochrome di semua '
        'layar (CategoryIcon lama dihapus).',
    breaking: null,
  ),
  (
    version: 'v1.10.0',
    date: '8 Okt 2026',
    user:
        'Beranda baru: kartu saldo berwarna, progress budget lebih jelas, '
        'tombol Catat melayang yang mudah dijangkau jempol.',
    tech:
        'Beranda baru: kartu saldo aksen + teks putih, progress budget '
        'bertrack, nama kategori lebih besar, ikon monochrome aksen, teks '
        'transaksi kontras, tombol Catat jadi FAB melayang.',
    breaking: null,
  ),
  (
    version: 'v1.9.0',
    date: '7 Okt 2026',
    user: 'Tampilan Kategori, Pengaturan, dan Kunci Layar baru yang seragam.',
    tech:
        'Redesign STEP 4: Kategori + Pengaturan + Lock Screen baru (visual '
        'saja, logika utuh).',
    breaking: null,
  ),
  (
    version: 'v1.8.0',
    date: '7 Okt 2026',
    user:
        'Budget bisa diedit dan dihapus dengan aman (ada tombol urungkan 5 '
        'detik kalau salah hapus), plus ringkasan “X dari Y aman”.',
    tech:
        'Budget rapi: edit beneran + hapus aman + undo 5 detik + validasi '
        'inline + overview aman.',
    breaking: null,
  ),
  (
    version: 'v1.7.2',
    date: '7 Okt 2026',
    user: 'Perbaikan: budget yang baru disimpan sekarang langsung muncul di daftar.',
    tech: 'Fix list budget tetap kosong setelah simpan + SnackBar tersimpan.',
    breaking: null,
  ),
  (
    version: 'v1.7.1',
    date: '7 Okt 2026',
    user: 'Perbaikan: tombol Tambah Budget sekarang langsung membuka dialog.',
    tech: 'Fix tombol Tambah Budget: dialog instan + SnackBar bila belum lengkap.',
    breaking: null,
  ),
  (
    version: 'v1.7.0',
    date: '7 Okt 2026',
    user: 'Tampilan Budget dan Laporan baru yang lebih jelas dan rapi.',
    tech:
        'Redesign STEP 3: navigasi bawah custom + Budget + Laporan baru '
        '(visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.6.0',
    date: '7 Okt 2026',
    user: 'Tampilan Riwayat dan Form Catat baru yang lebih nyaman dipakai.',
    tech: 'Redesign STEP 2: Riwayat + Form Transaksi baru (visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.5.0',
    date: '7 Okt 2026',
    user: 'Tampilan Beranda baru yang lebih bersih dan modern.',
    tech: 'Redesign STEP 1: tokens + TxTile + Beranda baru (visual saja).',
    breaking: null,
  ),
  (
    version: 'v1.4.0',
    date: '7 Okt 2026',
    user:
        'Pengaturan kini multi-halaman dan bisa dicari, nominal otomatis '
        'bertitik saat diketik.',
    tech:
        'Pengaturan multi-halaman + input nominal otomatis bertitik + border '
        'seragam.',
    breaking: null,
  ),
  (
    version: 'v1.3.0',
    date: '7 Okt 2026',
    user:
        'Pengaturan dirapikan (ada kolom cari + kelola kategori sendiri), '
        'Beranda dapat ringkasan harian.',
    tech:
        'Restruktur Pengaturan (cari, 4 grup, kelola kategori sendiri, tentang '
        'tap-to-copy) + ringkasan harian di Beranda.',
    breaking: null,
  ),
  (
    version: 'v1.2.1',
    date: '7 Okt 2026',
    user: 'Warna angka pemasukan/pengeluaran ikut tema HP.',
    tech: 'Warna semantik ikut colorScheme + palet pie tanpa hijau.',
    breaking: null,
  ),
  (
    version: 'v1.2.0',
    date: '7 Okt 2026',
    user:
        'Tampilan full: 6 warna aksen pilihan, mode hitam pekat, saldo bisa '
        'disembunyikan, Beranda bisa dikustom sesukamu.',
    tech:
        'Tampilan full (aksen, Material You, true black, privacy all, nominal '
        'ringkas, kustom Beranda, overkill).',
    breaking: null,
  ),
  (
    version: 'v1.1.0',
    date: '7 Okt 2026',
    user:
        'Halaman Pengaturan pertama: tema, kunci PIN, pengingat harian, dan '
        'backup data.',
    tech: 'P0 Pengaturan + bottom bar baru.',
    breaking: null,
  ),
  (
    version: 'v1.0.1',
    date: '7 Okt 2026',
    user: 'Perbaikan: saldo langsung berubah setiap ada transaksi baru.',
    tech: 'Fix saldo reaktif.',
    breaking: null,
  ),
  (
    version: 'v1.0.0',
    date: '7 Okt 2026',
    user: 'Rilis pertama: catat pemasukan-pengeluaran harian, 100% offline.',
    tech: 'MVP awal.',
    breaking: null,
  ),
];

/// Teks siap tampil / siap salin (dipakai halaman Changelog + laporan bug).
String formatChangelog() => appChangelog
    .map((e) => '${e.version} (${e.date}) — ${e.user}')
    .join('\n\n');
