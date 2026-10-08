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

## v1.13 — Berikutnya
- [ ] Multi-dompet (Tunai / Bank / E-wallet) + transfer antar dompet.
- [ ] Transaksi berulang (langganan bulanan otomatis tercatat).

## Backlog — Data aman & berguna
- [ ] Rencana menabung / target (sinking fund).
- [ ] Insight sederhana: "pengeluaran makan naik 20% vs bulan lalu".

## Nanti / butuh riset
- Scan struk (OCR) — butuh ML Kit / layanan OCR.
- Sinkronisasi antar-HP / cloud — mengubah asumsi offline-first, desain dulu di [[02-Arsitektur]].
- Export PDF laporan bulanan.

## Catatan keputusan
Arsitektur saat ini (Drift + Riverpod stream) sudah cukup sampai v1.2. Multi-dompet = tambah tabel `wallets` + kolom `walletId` di transactions + migrasi schema v1→v2.
