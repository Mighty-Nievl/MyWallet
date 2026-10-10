# 06 — Roadmap

Urut saran pengerjaan setelah MVP stabil dipakai 2–4 minggu.

## v1.1 — Privasi & kebiasaan ✅ (rilis 7 Okt 2026 sebagai v1.1.0)
- [x] Kunci aplikasi (PIN / biometrik) — privasi itu alasan #1 orang mau pakai pencatat lokal.
- [x] Pengingat harian mencatat (notifikasi lokal, `flutter_local_notifications`).
- [x] Saldo awal / koreksi saldo (masuk P0 Pengaturan).
- [x] Backup (file `.sqlite` via `VACUUM INTO` + restore + hapus semua data) — dimajukan dari v1.3 karena kritis untuk app offline.
- [x] Tema gelap/terang + sembunyikan saldo.
- [ ] Input cepat: parsing "makan 25 ribu" dari satu kolom.

## v1.2 — Tampilan full ✅ (rilis 7 Okt 2026 sebagai v1.2.0)
- [x] Warna aksen (6 pilihan) + Material You / dynamic_color.
- [x] Hitam pekat mode gelap, privacy semua nominal, nominal ringkas (Rp1,5 jt).
- [x] Kustom Beranda (ringkasan / top kategori / terakhir 3-5-10).
- [x] Overkill: ukuran font, list rapat, tanggal relatif, ikon kategori on/off.

## v1.3 — Pengaturan rapi + ringkasan harian ✅ (rilis 7 Okt 2026 sebagai v1.3.0)
- [x] Restruktur Pengaturan: kolom cari, 4 grup (Tampilan / Saldo & Privasi / Kelola / Tentang), Isi Beranda jadi sub-bagian, Kelola kategori halaman sendiri, hirarki Data, Tentang tap-to-copy + changelog.
- [x] Ringkasan harian di Beranda (masuk / keluar / selisih hari ini, ikut privacy + nominal ringkas, toggle di Isi Beranda).

## v1.4 — Pengaturan multi-halaman + input rapi ✅ (rilis 7 Okt 2026 sebagai v1.4.0)
- [x] Pengaturan multi-halaman: hub 4 grup (Tampilan / Saldo & Privasi / Kelola / Tentang) + cari global yang lompat ke sub-halaman + query ikut diteruskan.
- [x] Input nominal otomatis bertitik (ketik `1000` → `1.000`) di form catat, budget, saldo awal (parse tetap via `parseRp`).
- [x] Border input seragam global (radius 16 + `outlineVariant`, fokus aksen) via `inputDecorationTheme` — hapus semua border manual.

## v1.5 — Redesign STEP 1 ✅ (rilis 7 Okt 2026 sebagai v1.5.0)
- [x] Design tokens ala shadcn (`lib/ui/design/`: warna netral, spacing, radius, tipografi) + komponen (`lib/ui/components/`: kartu subtle, section, ikon kategori).
- [x] TxTile baru (baris bersih: ikon subtle, judul, info muted, nominal tegas) — API tetap.
- [x] Beranda baru (header custom, saldo kartu subtle, kategori tanpa kartu, riwayat tanpa kartu) — logika/provider/query tidak berubah.
- [x] Tema: latar netral restrained, kartu tanpa shadow + border tipis, radius kartu 14 / input 12. Aksen, dynamic color, true black, compact, font scale tetap.

## v1.6 — Redesign STEP 2 ✅ (rilis 7 Okt 2026 sebagai v1.6.0)
- [x] Riwayat baru: header custom + navigasi bulan ala Beranda + chip filter kompak + empty/loading state minimal — search/filter/list/tap-edit/logika tidak berubah.
- [x] Form transaksi baru: header kembali/hapus + tipe SegmentedButton diselaraskan + nominal hero (Rp + angka besar, formatter tetap) + kategori bottom sheet + tanggal tile + Simpan 52px + Hapus terpisah — CRUD/validasi/dialog/navigasi tidak berubah.

## v1.7 — Redesign STEP 3 ✅ (rilis 7 Okt 2026 sebagai v1.7.0)
- [x] Navigasi bawah custom MyWallet (bar ramping + garis subtle, aktif = pil aksen, Catat = tombol aksen penuh) — destinasi & perilaku tetap.
- [x] Budget baru: header + month-nav + overview (total batas/terpakai/progress) + item per kategori + dialog tambah/edit — CRUD/perhitungan/threshold tidak berubah.
- [x] Laporan baru: header + month-nav + ringkasan (Masuk/Keluar/Selisih) + bar 6 bulan + pie + rincian konsisten Home — fl_chart & data tetap.
- [x] Komponen reuse baru: `app_header`, `app_month_nav`, `app_progress`, `app_empty_state`.

## v1.7.1 — Fix Budget ✅ (rilis 7 Okt 2026 sebagai v1.7.1)
- [x] Fix tombol Tambah Budget: dialog terbuka instan (kategori dimuat di dalam dialog via Consumer) + SnackBar bila kategori/batas belum lengkap + dispose controller.

## v1.7.2 — Fix Budget refresh ✅ (rilis 7 Okt 2026 sebagai v1.7.2)
- [x] Fix list tetap "Belum ada budget" setelah simpan: trigger `budgetsProvider` dengarkan tabel budgets + transactions (sebelumnya cuma transactions) + SnackBar "Budget tersimpan.".

## v1.8 — Budget P0+P1 ✅ (rilis 7 Okt 2026 sebagai v1.8.0)
- [x] Item bisa di-tap → dialog edit beneran (kategori dikunci, batas prefill, judul bulan dinamis) + info timpa eksplisit (bukan diam-diam).
- [x] Hapus: konfirmasi ala TxForm + SnackBar undo 5 detik (hapus langsung di list dihapus).
- [x] Validasi inline (errorText) + kategori tambah via bottom sheet ala TxForm + lompat ke Kelola kategori bila kosong + autofocus + submit keyboard + cegah double-tap.
- [x] Overview jawab "aman nggak": label bulan dinamis + total sisa/lewat + progress tebal + "X dari Y budget aman"; aman = muted.
- [x] Tombol tambah satu gaya Filled 52px + aksi cepat + di header; error ramah + "Coba lagi"; urutan stabil abjad (sort di `fetchBudgets`).
- [x] Logika provider dicabut ke `fetchBudgets` + `monthRangeOf` (testable) + 6 test budget in-memory (upsert/update/bulan/delete/filter/spent). 33/33 hijau.

## v1.9 — Redesign STEP 4 ✅ (rilis 7 Okt 2026 sebagai v1.9.0)
- [x] Kategori: header custom + grup Pengeluaran/Pemasukan + baris konsisten TxTile + hapus 48px + dialog SegmentedButton semantik + validasi inline + hapus destruktif merah + error ramah + coba lagi.
- [x] Pengaturan: `SettingRow` + `SettingsGroup` + `BackHeader` baru (ikon kotak subtle + judul + deskripsi + kontrol, divider otomatis, kembali berboder); hub + 4 sub-halaman + Tentang satu bahasa; navigasi, filter cari, semua setter TETAP.
- [x] Dialog pilih: `_pickSingle` + `_PickRow` (ikon + cek) untuk tema/privacy-scale/recent/lock; aksen jadi grid dot kompak `_AccentDot`; PIN inline-error; destruktif merah konsisten; teks & urutan opsi TETAP.
- [x] Lock Screen: hierarki MyWallet → 🔒 → "Aplikasi terkunci" → PIN 52px + biometrik; controller/validasi/auth/obscure/keyboard/error/loading TETAP.
- [x] Aksen/dynamic/true-black/compact/font-scale/light/dark: semua lewat colorScheme + token lama, tidak ada hard-code. 33/33 hijau.

## v1.10 — Beranda baru ✅ (rilis 8 Okt 2026 sebagai v1.10.0)
- [x] Kartu saldo: background aksen utama (`scheme.primary`, ikut pilihan user/Material You — bukan hijau hard-code) + teks putih; "Hari ini" tetap putih.
- [x] Progress kategori: `AppProgress` dengan track abu terang (`surfaceContainerHighest`, batas 100% kelihatan) + fill aksen; dipakai Beranda/Budget/Laporan.
- [x] Tipografi: nama kategori `bodyLarge/w600`; tanggal/deskripsi transaksi pakai `secondaryStrong` kontras (`#424242` light / `#E0E0E0` dark).
- [x] Ikon: `CategoryGlyph` monochrome aksen (mapping emoji→Material outlined, DB tidak diubah, fallback generik); dipakai TxTile + top kategori.
- [x] Navigasi: tombol Catat jadi FAB lingkaran melayang (`centerDocked`) + tooltip; tab aktif tetap pil aksen. 35/35 hijau.

## v1.10.1 — Penyeragaman ✅ (rilis 8 Okt 2026)
- [x] FAB Catat tertanam: bar bawah `Container` → `BottomAppBar` + `CircularNotchedRectangle` (notch kepotong otomatis, tombol bernaung di bar bukan melayang tipis).
- [x] Beranda: `ListView` → `CustomScrollView`, tepat satu `SliverToBoxAdapter` + `ValueKey` per section (`home:header/monthnav/balance/daily/topcats/recent`) — tidak ada jalur render ganda.
- [x] Ikon monochrome di semua layar: 11 titik `CategoryIcon` → `CategoryGlyph` (Budget 4, Kategori, Riwayat empty, Laporan, TxForm 3, empty-state generik); file `category_icon.dart` dihapus; DB emoji tidak diubah.

## v1.10.2 — Fix bar bawah ✅ (rilis 8 Okt 2026)
- [x] Blok hitam belang hilang: buang `SafeArea` pembungkus `BottomAppBar` (safe area diurus SafeArea internal di dalam material bar — background ikut warna bar).
- [x] Notch rapat: `extendBody: true` + `BottomAppBar` langsung tanpa wrapper sehingga cekungan `CircularNotchedRectangle` kepotong tepat di bawah FAB; satu akar dua gejala (SafeArea luar menggeser bar + miss notch).

## v1.11 — Logo + Micro-UX ✅ (rilis 8 Okt 2026 sebagai v1.11.0)
- [x] Logo: `assets/images/app_logo.png` (dompet hijau + koin emas) → ikon launcher Android (5 densitas) + ICO Windows + tampil di Lock + Tentang; nama OS `mywallet` → `MyWallet` (manifest + window + exe metadata; title in-app sudah benar).
- [x] FAB Container Transform: `OpenContainer` (`animations`, fade 450ms, `tappable: false`) — tombol melebar mulus jadi form Catat; haptic dulu baru transisi (tanpa ini tap bisa dobel).
- [x] Zero-friction: nominal `autofocus` hanya mode tambah + quick-add `ActionChip` (Bensin/Jajan/dll, pemasukan terpisah) — mode edit tidak autofocus/chip.
- [x] Haptic: FAB + pilih kategori (`selectionClick`) + simpan sukses (`lightImpact`).
- [x] Empty state memotivasi: Beranda top-kategori + terakhir (ramah, ajak catat), Riwayat (ubah bulan/filter) — via `AppEmptyState` generik.

## v1.12 — Beranda Insight ✅ (rilis 8 Okt 2026 sebagai v1.12.0)
- [x] Header sapaan pinned ("Selamat pagi/siang/sore/malam" + tanggal) — tombol Pengaturan tidak ikut scroll hilang; hero netral gelap (#171717) + arus bulan semantik (masuk hijau terang / keluar merah terang) + delta % vs bulan lalu + pacing budget (Aman/Hampir habis/Lewat, ambang 80% sama kayak Budget).
- [x] Bahasa visual satu: top kategori proporsional thd total + persen per baris; "Hari ini" jadi strip ringkas masuk/keluar/selisih; terakhir dikelompokkan per tanggal + chevron (seluruh baris tap→edit kelihatan affordancenya).
- [x] Navigasi M3: `BottomAppBar` + notch + spacer manual → `NavigationBar` + FAB endFloat mengambang (OpenContainer transform TETAP); magic numbers dicairkan jadi token (`bottomPad`, `touchMin`); `circular(10)` liar → `AppRadius.mdAll`; label chart 11px → 12px.
- [x] Feedback konsisten: `AppSkeleton` shimmer + `AppErrorState` ("…gagal dimuat." + Coba lagi, tanpa bocor `$e`) di Beranda/Riwayat/Budget/Laporan/Form/Kategori/Pengaturan; `AppHeader` + `AppMonthNav` shared dipakai semua layar (duplikat `_Header`/`_MonthNav` dihapus); label hero eksplisit "Saldo semua waktu" agar tidak dikira saldo bulan.
- [x] Logika/provider/query/CRUD/perhitungan/navigasi TIDAK berubah — 35/35 hijau.

## v1.12.1 — Polish Beranda ✅ (rilis 8 Okt 2026 sebagai v1.12.1)
- [x] Semantik nominal satu sumber: `AppColors.incomeOf/expenseOf` (+ varian `incomeOnDark/expenseOnDark` untuk hero #171717) dipakai hero + strip hari ini + TxTile — tidak ada dua palet hijau/merah beda kadar; kontras hero vs #171717 diukur eksplisit ≥4.5:1 (WCAG AA) di light + dark.
- [x] Delta % vs bulan lalu via `FutureProvider` (`_prevMonthExpenseProvider`) — query jalan sekali per bulan, tidak diulang tiap rebuild (sebelumnya `FutureBuilder` di dalam build).
- [x] CTA "Atur budget" saat budget kosong (lompat ke tab Budget) + strip hari ini satu baris jelas saat nol transaksi + hero berboder di dark mode agar tidak menyatu latar.
- [x] Golden test Beranda (`test/home_design_test.dart` + `test/goldens/`): hero light + hero dark tanpa budget + uji kontras; README baru ala landing page (logo + badge + tabel fitur). 38/38 hijau.

## v1.13 — Beranda GoPay ✅ (rilis 8 Okt 2026 sebagai v1.13.0)
- [x] Kepala sapaan berwarna aksen (lebih gelap dari kartu) + kartu saldo gradien 2-stop IKUT warna aksen tema (hijau default, biru ala GoPay, dst via Pengaturan → Tampilan); tiap stop digelapkan sampai teks putih lolos kontras ≥5.0 (margin atas WCAG 4.5).
- [x] Kartu ringkas (saldo + tombol Catat/Riwayat) + deretan aksi cepat (Catat/Riwayat/Budget/Laporan) + banner insight gelap (delta % via provider + pacing budget Aman/Hampir habis/Lewat + CTA Atur budget) + tile metrik (Masuk bulan / Keluar bulan / Hari ini).
- [x] Test kontras 6 aksen × 2 tema × (2 stop gradien + kepala) = 48 pengukuran dari widget yang benar-benar dirender (minimum 5.04:1 blue/dark); golden regen pola baru. 38/38 hijau.
- [x] Regresi overflow CI (font fallback Linux lebih lebar): Row hero + status budget + kategori cepat dibungkus Expanded/Flexible + ellipsis; test viewport sempit 300px permanen agar jebol duluan di lokal. 39/39 hijau.

## v1.13.1 — Mockup GoPay ✅ (rilis 8 Okt 2026 sebagai v1.13.1)
- [x] Sapaan personal “Hai, {nama}!” + ikon mahkota (setting baru Pengaturan → Tampilan → Nama sapaan, default Nievi, kosong = “Hai!”) + tanggal panjang “Rabu, 8 Oktober 2026” + avatar inisial (ketuk = Pengaturan) + lonceng pengingat + gear; status bar transparan ikon terang.
- [x] Kepala disusun ulang persis mockup: blok gelap menepi tepi atas, kartu saldo MENUMPUK separuh masuk blok & separuh keluar ke halaman terang (radius 16, bayangan lembut); label “SALDO MYWALLET”, mata saldo terlipat, pil aksi 39px (putih solid + dua pil putih 15%).
- [x] Nav bulan hanya muncul saat menjelajah bulan lain; aksi cepat 4 chip (Catat/Pemasukan/Budget/Laporan); tile Masuk OKT / Keluar OKT / SISA BUDGET (hari tersisa); ringkasan “Hari ini” pindah ke seksi Terakhir dicatat; kartu dijenuhkan +35% selaras seed mockup, kontras putih tetap ≥4.5:1 (48 pengukuran, min 4.76:1). 39/39 hijau.

## v1.14 — Export PDF + Scan struk (rilis 8 Okt 2026 sebagai v1.14.0)
- [x] Export PDF laporan bulanan 100% offline: `lib/data/report_pdf_service.dart` (fetch via `monthRangeOf` + `getTotals` + `totalsByCategory` + `watchHistory`, bangun `pdf` lokal, keluar via share sheet / simpan file — tanpa server/API-key, meniru pola `exportCsv()` + backup); tombol PDF di header Laporan + baris baru di Kelola; hasil: judul + ringkasan Masuk/Keluar/Selisih + rincian kategori (%) + daftar transaksi (tanggal/tipe/kategori/nominal).
- [x] Scan struk on-device Fase A: `image_picker` (kamera/galeri, izin CAMERA baru) → `google_mlkit_text_recognition` (latin, 100% di HP) → teks → `lib/data/receipt_parse.dart` (fungsi murni: regex TOTAL/Grand Total abaikan TUNAI/KEMBALI, fallback angka terbesar non-tunai, tanggal numerik + "8 Okt 2026", merchant baris pertama, saran kategori word-boundary 7 kategori) → prefill form Catat (nominal selalu; tanggal/catatan/kategori hanya bila cocok + kolom kosong); tombol scan di header form + bottom sheet kamera/galeri; logika `_save()`/`addTransaction` TETAP (user cek manual + Simpan).
- [x] Test baru `test/receipt_pdf_test.dart` (20 kasus: parse uang ID/EN, TOTAL vs tunai, grand total, fallback, tanggal, 7 kategori incl. anti-false-positive "tol di botol", PDF header %PDF- + bulan kosong). analyze bersih, 59/59 hijau.

## v1.15 — Manajer utang-piutang (rilis 9 Okt 2026 sebagai v1.15.0)
- [x] Dua tabel baru (`debts` + `debt_payments`) + 2 kolom tautan di `transactions` + migrasi v1→v2 aman (data lama utuh, kolom nullable, tabel kosong). Skema: `docs/03-Skema-Database.md`.
- [x] Semantik saldo OTOMATIS (opsi B): utang = pinjam (catat = pemasukan, bayar = pengeluaran), piutang = meminjami (catat = pengeluaran, terima = pemasukan) — tiap catat/bayar menulis transaksi CERMIN (`debtId`/`debtPaymentId`) sehingga saldo + laporan + riwayat + PDF + CSV ikut tanpa ubah satu pun query lama. `lib/data/debt_actions.dart` (inti testable `insertDebt/insertDebtPayment/updateDebt/deleteDebt/deleteDebtPayment` + wrapper `WidgetRef` tipis).
- [x] Cicilan parsial berkali-kali (opsi A) + anti-overpay (`DebtOverpayException` + error inline) + jatuh tempo opsional (LEWAT merah) + progress + lunas otomatis (dihitung `paid >= total`, tidak disimpan). Urutan: aktif dulu (tempo dekat), lunas abjad.
- [x] Tab Utang ke-5 (`handshake` icon) + kartu ringkas Beranda (sisa utang vs piutang, sembunyi bila kosong, Kelola → tab 4) — bottom nav melebar dari 4 ke 5, `onGoTab` Beranda tetap.
- [x] Layar `DebtScreen`: overview + seksi Aktif/Lunas + dialog catat/ubah (tipe SegmentedButton, dikunci saat ubah) + bottom sheet detail + dialog bayar + konfirmasi hapus (tanpa undo, cermin banyak). Komponen reuse: AppHeader/AppCard/AppProgress/AppEmptyState/AppSection/CategoryGlyph + `ThousandSeparatorInputFormatter` + `display.money/date`.
- [x] Test `test/debt_test.dart` (15 kasus: cermin masuk/keluar, 2x cicilan, overpay, pas-lunas, validasi, urutan, ubah sinkron, hapus total, hapus cicilan, ringkasan) + `test/debt_widget_test.dart` (6 kasus: empty, list, dialog end-to-end + saldo, validasi inline, kartu Beranda + lompat tab). analyze bersih, 85/85 hijau.

## v1.16 — Sync-ready + keluarga (jalan: Fase 0 ✅ 10 Okt 2026)

Rencana: simpan online + pasangan ikut nyatat (Google Sign-In + Firestore, opsi B — pilih user 10 Okt 2026). Tetap offline-first: tanpa login = app sekarang, nol berubah.

- [x] **Fase 0 — sync-ready lokal (v1.16.0, tanpa network)**: skema v3 (`uuid/updatedAt/deletedAt/householdId` di 5 tabel + `categoryUuid`), migrasi v2→v3 + backfill otomatis, `sync_meta.dart`, semua query siap soft-delete (`deletedAt IS NULL`), `actions`/`debt_actions` bump `updatedAt`. Test `sync_ready_test.dart` 9 kasus. Offline 100% sama, full suite 94/94 hijau.
- [x] **Rename + wiring Firebase (v1.16.1, tetap offline)**: package `com.nievl.mywallet` → `com.rezal.mywallet` (MainActivity pindah paket, namespace + applicationId + docs), plugin `google-services` 4.5.0, `firebase_core` init aman-gagal di `main.dart`, paket `firebase_auth` + `cloud_firestore` + `google_sign_in` v7, `minSdk` 23, `google-services.json` (project `mywallet-7614d`) di-gitignore + CI via secret `GOOGLE_SERVICES_JSON_BASE64`. CATATAN: ganti package = install app baru di HP (backup dulu via Kelola).
- [x] **Fix restore/wipe (v1.16.2)**: `BackupService` tulis ulang — path DB langsung (`mywallet.sqlite`, tanpa `PRAGMA`), urutan path → close → copy/hapus di dalam service, WAL checkpoint sebelum backup, header SQLite divalidasi (tolak file sampah). Test `backup_file_test.dart` 9 kasus, full suite 103/103.
- [x] **Fase 1 — auth + household (v1.17.0)**: login Google (`google_sign_in` v7 → `GoogleAuthProvider.credential`), buat/gabung rumah tangga + kode invite 8 char 24 jam + putar kode, cache sesi lokal (boot offline), layar Keluarga di Pengaturan, `firestore.rules` anggota-only (koleksi sync `tx/cats` ditolak sampai Fase 2). Test `household_test.dart` 14 kasus, full 122/122. SYARAT SERVER: Auth Google Enable + Firestore `asia-southeast2` + SHA-1 debug+rilis + `google-services.json` baru (oauth).
- [x] **UX Keluarga (v1.17.1)**: hero empty-state + tombol Google 52px, error card inline + Coba lagi, `friendlyAuthError` diperluas, `AuthService` null-safe, `family_ux_test.dart`, full 127/127.
- [x] **Login siap (v1.17.2, config-only)**: SHA-1 debug+rilis terdaftar, Auth Google Enable, `google-services.json` baru (oauth 3), secret CI diperbarui. Tanpa perubahan kode.
- [x] **Anti-hang boot (v1.17.3)**: timeout 8 detik silent-login + `_sessionFor`, fallback signedIn/personal, `family_ux_test` +bootTimeout, full 128/128.
- [x] **Audit login (v1.17.4)**: timeout berlapis signIn + fallback signedIn, fix join via `householdName` di invite, pesan permission-denied, full 131/131. WAJIB: publish `firestore.rules` ke console.
- [x] **Keluarga + sapaan production-grade (v1.18.0)**: `isOfflineProvider` disable preemptif, `validateHouseholdName` max 40 + counter, `fetchMembers` + daftar anggota, share invite WA + fallback salin, `isOwner` guard putar kode, `greeting.dart` murni + copy baru, full 147/147.
- [x] **Pesan error jujur (v1.18.1)**: audit screenshot ReWin (WiFi on, 0,76 KB/S, tombol aktif + banner merah) — pisah timeout/deadline/aborted ("sinyal lemot") dari network/unavailable ("tanpa internet"), copy "tanpa sinyal", full 148/148.
- [x] Fase 2 — sync engine beta (v1.19.0, opt-in): push/pull transactions + categories + indikator status di Keluarga. Cermin utang TIDAK sync mentah (rebuild per-HP Fase 3) — rules tolak debtId. Hapus = soft-delete merambat (tombstone). Test `sync_engine_test.dart` 9 kasus, full 157/157. SYARAT SERVER: publish `firestore.rules` baru (cats/tx anggota-only).
- [x] **Kelola anggota + pengaman keluar (v1.19.1)**: baris Anggota bisa diketik → bottom sheet (naik/turun peran, keluarkan, keluar) + dialog konfirmasi + peringatan pengelola-terakhir (tidak diblokir); tombol Keluar utama juga konfirmasi + cek online; `canRemoveMember` guard murni + test 3 kasus; rules `members delete` owner-bisa-kick. Full 160/160.
- [x] **B2C total semua halaman (v1.20.0)**: token gerak `AppMotion` + `Stagger` entrance tanpa timer (aman fake_async) + progress animasi + empty-state medali gradien + `AppCard` shadow lembut + haptic global (tile/baris/tombol ikon/pil hero/segmented/export/PIN) + hero shine + stagger Beranda/Riwayat/Catat/Budget/Laporan/Utang/Kategori/Changelog + transisi fade-through. Nol teks/key/logika berubah. Full 160/160.
- [x] **Beranda papan kemenangan (v1.21.0)**: hero count-up + pacing budget di awal + tombol raksasa 56px + streak N hari + dots 7 + misi harian + Catat Kilat (`initialAmount`) + fix 3 bug visual QA golden. 3 test baru, full 163/163.
- [x] **Redesign Beranda editorial (v1.22.0)**: header strip ramping, hero ledger full-bleed (saldo 40px + Masuk/Keluar + budget + tombol 2 kolom), strip delta ganti banner ganda, golden regenerasi, logo redesigned + mipmap. Full 163/163.
- [x] **Beranda simple tanpa streak (v1.23.0)**: hapus kartu gamifikasi + provider + slot, stagger rapi 1-5, absence-test, golden regenerasi. Full 163/163.
- [ ] Fase 3 — utang + budget ikut sync + uji 2 emulator bareng.
- [ ] Fase 4 — hardening production-grade: RLS audit, hapus akun, kebijakan privasi (wajib Play Store), crash reporting.

## v1.17 — Berikutnya (tetap lokal)
- [ ] Multi-dompet (Tunai / Bank / E-wallet) + transfer antar dompet.
- [ ] Transaksi berulang (langganan bulanan otomatis tercatat).

## Backlog — Data aman & berguna
- [ ] Rencana menabung / target (sinking fund).
- [ ] Insight sederhana: "pengeluaran makan naik 20% vs bulan lalu".

## Nanti / butuh riset
- [x] Scan struk on-device Fase A (rilis v1.14.0: ML Kit + `receipt_parse.dart` murni + prefill form). Fase B opt-in cloud (kirim TEKS ke DocStruct/OCR.Space bila ML Kit gagal di struk lusuh) — belum dibangun, butuh kunci + izin eksplisit.
- Sinkronisasi antar-HP / cloud — mengubah asumsi offline-first, desain dulu di [[02-Arsitektur]].
- [x] Export PDF laporan bulanan (rilis v1.14.0: `pdf` + `printing` lokal via `report_pdf_service.dart`, tanpa API public-apis).

## Catatan keputusan
Arsitektur saat ini (Drift + Riverpod stream) sudah cukup sampai v1.2. Multi-dompet = tambah tabel `wallets` + kolom `walletId` di transactions + migrasi schema v3→v4 (v2→v3 sudah dipakai sync-ready di v1.16).
