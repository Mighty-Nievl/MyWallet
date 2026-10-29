# 07 — Rilis & Install via Obtainium

## Kenapa GitHub Releases?
Obtainium (updater open-source di HP) memantau halaman **GitHub Releases**, bukan Actions artifacts. Jadi tiap versi stabil diterbitkan sebagai Release berisi APK bertanda tangan → HP dapat notifikasi update otomatis.

## Riwayat rilis
- **v1.44.0** (29 Okt 2026): `app_lock` divalidasi whitelist `{none,pin,biometric}` di baca & tulis (`normalizeAppLock`) — nilai rusak jadi `none`, tidak lagi mengunci aplikasi padahal belum ada PIN (`verifyPin` selalu false tanpa hash). `SettingRow` cek null tak tercapai dibuang. Copy backup/restore menyebut isinya data saja; setelan sengaja tidak ikut file backup (appLock & PIN tak boleh ikut, format `.sqlite` lama tetap bisa direstore). 385 test hijau.
- **v1.43.0** (29 Okt 2026): audit arsitektur Pengaturan → satu katalog setelan (31 entri) sebagai sumber pencarian hub + filter sub-halaman (dulu daftar hardcoded 25 entri untuk 32 baris, 7 setelan tak bisa dicari); `SettingSwitch` + `SettingsScaffold` memangkas 526 baris; export CSV pindah ke `ExportService` (7 tes); setelan `showMonthTotals` yang yatim dibuang; `autoBackup` dibaca lewat provider (satu parser). 380 test hijau.
- **v1.42.0** (29 Okt 2026): Beranda satu rail — semua isi kartu (hero dompet, arus kas, baris transaksi) duduk di x=32, judul section tetap x=16; jarak dalam satu blok (hero → periode → arus kas) seragam 24 dan antar section tetap 32. Drift spacing sebelumnya (empat tepi teks: 16/28/32/40) tidak bisa kembali karena dikunci test kontrak. 368 test hijau.
- **v1.41.0** (23 Okt 2026): setiap simpan/hapus transaksi langsung memperbarui salinan (`runNow`), jadi "Backup terakhir: Baru saja" berarti data terakhir sudah ikut tersalin — bukan lagi menunggu jatah 20 jam. Nama file jadi satu per hari (`mywallet-auto-YYYYMMDD.sqlite`, simpan berikutnya menimpa) sehingga rotasi 5 = lima hari terakhir, dan start tidak lagi gagal bila file DB belum terbuka (retry 400 ms). 366 test hijau.
- **v1.40.0** (23 Okt 2026): catat satu kolom — `parseQuickInput` membaca nominal dari teks Catatan (ribuan bertitik, angka + satuan rb/k/jt, angka polos ≥4 digit; <1000 tanpa satuan dan >Rp1 triliun ditolak). Form menampilkan helper "Terbaca Rp25.000 — dipakai saat simpan" dan memakai hasil parse hanya bila kolom nominal kosong, jadi angka yang diketik user tidak pernah ditimpa. 15 test baru, 365 test hijau.
- **v1.39.0** (23 Okt 2026): backup harian otomatis — `AutoBackupBinder` memicu `AutoBackupController` pada `start`/`resume` (maks. sekali per 20 jam, diam bila switch mati, tidak pernah melempar), menyalin DB setelah `wal_checkpoint(TRUNCATE)` ke `backups/mywallet-auto-YYYYMMDD-HHMM.sqlite` di dokumen app dengan rotasi 5 terbaru. Pengaturan → Kelola dapat baris "Backup otomatis" (default ON), "Backup terakhir" + tombol "Sekarang" (melewati jatah), dan "Pulihkan backup otomatis" (pilih salinan di HP; dialog konfirmasi sama dengan restore manual). 16 test baru, 350 test hijau.
- **v1.38.7** (22 Okt 2026): di filter **Harian**, "Pengeluaran hari ini" (`home:topcats`) naik di atas "Terakhir dicatat" (`home:recent`); periode lain tidak berubah. Urutan kini dari `dailyFirst = period.kind == PeriodKind.harian` + dua daftar sliver lokal, dijaga test urutan `dy` di `home_design_test.dart`. 334 test.
- **v1.38.6** (22 Okt 2026): label periode di `PeriodNav` tidak lagi disabled — dulu `onPressed: null` saat `isCurrent` membuat M3 menimpa warna jadi 3,4:1 (gagal AA) di state default. Chip periode aktif dapat border `onPrimaryContainer` 1,5dp (~13:1) supaya seleksi menang dari border idle 7,36:1, tanpa menurunkan idle di bawah ambang 3:1. 333 test.
- **v1.38.5** (22 Okt 2026): sync otomatis — `start`/`resume`/`online` lewat `AutoSyncController` (start sekali per sesi, resume & online dijatah 2 menit, diam saat offline/tanpa rumah tangga, tidak pernah melempar). Test migrasi pertama di repo: v4→v5 lewat `NativeDatabase.memory(setup:)` + `PRAGMA user_version=4` (data & PK utuh, `is_shared` default privat) dan `onCreate` v5 (seed kategori + dompet Utama). 332/332 test hijau.
- **v1.38.4** (22 Okt 2026): hapus transaksi tanpa dialog konfirmasi — soft-delete tombstone sejak Fase 2 membuat "tidak bisa dikembalikan" itu keliru; kini langsung hapus + SnackBar "Urungkan" 6 detik (`restoreTransaction`). Menu "Budget" jadi "Anggaran" di 8 string. Dua file test penjaga baru: rasio kontras 20 pasangan token (light+dark, 4,5:1 / 3:1) dan restore transaksi. 320/320 test hijau.
- **v1.38.3** (22 Okt 2026): baris filter periode dirapikan — centang M3 yang ternyata cuma 1,4:1 (tak terbaca) tapi memakan 37dp lebar dihapus, padding 16→12dp, jadi keempat pilihan harian/mingguan/bulanan/tahunan muat utuh di 390dp tanpa scroll (dulu "Tahunan" terpotong di tengah huruf). Kontras label idle 2,23:1 → ~9:1, border chip 1,91:1 → ~4,4:1, label periode 3,88:1 → onSurface. Ikon Kalender pindah dari chip ke-5 yang tak pernah terlihat ke baris navigasi periode. 314/314 test hijau.
- **v1.38.2** (22 Okt 2026): kotak gelap di belakang indikator halaman dihapus — diukur dari screenshot v1.38.1 hanya 1,31:1 terhadap kartu dan memakan 21% tinggi kartu untuk tiga titik. Titik putih kini langsung di kartu (7,05:1 aktif / 4,99:1 non-aktif), pitch dirapatkan ke 24px, dan tombol kelola dompet jadi ikon putih polos seperti mata saldo. 309/309 test hijau.
- **v1.38.1** (22 Okt 2026): indikator halaman kartu dompet kini mengambang di tengah bawah kartu saldo — halaman aktif jadi garis pendek, lainnya titik, dan tombol kelola dompet jadi ikon gerigi di kanan baris. Baris dot lama (40px) hilang sehingga kartu lebih lega. 309/309 test hijau.
- **v1.38.0** (22 Okt 2026): Beranda punya halaman **Semua dompet** (total gabungan semua dompet, dipakai sebagai default) dan mode onboarding untuk user tanpa transaksi: satu tombol "Catat pengeluaran pertama" + scan struk, sementara switcher periode, kartu arus kas, kategori, dan riwayat disembunyikan sampai ada data. 308/308 test hijau.
- **v1.37.1** (22 Okt 2026): Penanda dompet di Beranda dibetulkan — dompet aktif ditandai pil panjang (bukan cuma beda warna 1,6:1 yang praktis tak terlihat), jarak antar titik kembali rapat setelah sempat direnggangkan target sentuh 48px, TalkBack menyebut dompet mana yang aktif, dan "Kelola dompet" dipisah ke kanan. 306/306 test hijau.
- **v1.37.0** (22 Okt 2026): Beranda lebih fokus ke data — periode tepat di atas kartu masuk/keluar, transaksi terakhir naik sebelum kategori, menu dipangkas jadi 4 pintasan unik, dan kartu Pemasukan/Pengeluaran membuka Riwayat yang sudah terfilter. Kelola dompet kini tombol terpisah; dots carousel hanya muncul bila dompet lebih dari satu. 305/305 test hijau.
- **v1.36.2** (21 Okt 2026): Sync keluarga kini hanya mengirim dompet bertanda Keluarga + transaksinya; dompet pribadi tidak lagi ikut ke cloud. Saldo awal ikut sync, transfer tidak bisa diedit/dihapus satu sisi, Undo budget benar-benar mengembalikan, dompet arsip bisa dipulihkan, dan instalasi baru langsung punya dompet Utama. **WAJIB publish `firestore.rules` baru** sebelum sync keluarga (field `openingBalance`). 305/305 test hijau.
- **v1.36.1** (21 Okt 2026): Tanggal form catat ikut periode yang sedang dilihat (tidak lagi selalu hari ini), export PDF mengikuti periode di Laporan, aplikasi terkunci lagi saat ditinggal ke background (route yang terbuka ikut tertutup), pintu kalender ganda di Riwayat dihapus, Budget diberi penanda selalu bulanan, dan grup Pengaturan dinamai jujur "Saldo, Privasi & Pengingat".
- **v1.36.0** (21 Okt 2026): Beranda & Riwayat ikut periode Harian/Mingguan/Bulanan/Tahunan, plus kalender grid dengan total harian (ketuk tanggal → rincian harian). Kartu masuk/keluar ikut periode; tombol + jadi 64px dengan overlap 8px.
- **v1.35.0** (21 Okt 2026): Laporan bisa dilihat per hari, minggu, bulan, atau tahun — ringkasan & rincian kategori ikut rentang, perbandingan memakai rentang sebelumnya yang setara.
- **v1.34.0** (21 Okt 2026): Dua kartu arus kas di Beranda — Pemasukan & Pengeluaran periode aktif dengan perbandingan bulan sebelumnya; ketuk untuk membuka Riwayat.
- **v1.33.1** (21 Okt 2026): Teks di dekat bilah bawah memudar halus (tidak terpotong garis), ketukan Riwayat/Scan terasa balasannya, label tetap rapi di font besar, dan bilah bawah menyingkir saat menggulir.
- **v1.33.0** (21 Okt 2026): Bilah bawah kini benar-benar melayang di atas layar — konten tergulir di belakangnya, posisinya tetap rapi di HP dengan navigasi gestur.
- **v1.29.0** (13 Okt 2026): Tiap dompet punya kartu saldonya sendiri di Beranda — geser untuk pindah dompet (kartu tampil = filter aktif). Urutan kartu diatur drag dari Kelola dompet (tersinkron antar-HP).
- **v1.29.1** (14 Okt 2026): Tombol Beranda di bawah jadi pintasan Riwayat. Kelola dompet pindah ke kartu bergambar gear di ujung kartu saldo. Lingkaran + tengah diperbaiki agar tampil utuh di semua HP.
- **v1.30.0** (14 Okt 2026): Kartu Kelola sejajar kartu saldo + titik halaman sampai kartu terakhir. Transaksi dan judul menyebut nama dompet (bila lebih dari satu). Tombol/kartu lebih membulat dan lembut di seluruh aplikasi.
- **v1.30.1** (14 Okt 2026): Daftar Terakhir dicatat lebih lega (jarak antar kartu). Bentuk kartu dan gambar ikon dirampingkan. Tombol kembali tampil polos tanpa kotak.
- **v1.31.0** (14 Okt 2026): Kartu riwayat tanpa panah + jarak lega. Kartu saldo fokus angka, ketuk untuk rincian dompet (riwayat, budget, utang, pindah dana, laporan, pengaturan). Form catat jelas ke dompet mana. Tombol + diperbesar, bilah navigasi ramping.
- **v1.32.0** (14 Okt 2026): Bilah bawah lebih ramping, tombol catat rincian dompet melayang. Rincian dompet punya pengaturan sendiri: ganti nama, saldo awal, arsip, dan tombol dompet dikelola keluarga atau pribadi.
- **v1.32.1** (14 Okt 2026): Bilah bawah kini dock kompak di tengah (tidak selebar layar), tombol + tetap besar menonjol.
- **v1.32.2** (14 Okt 2026): Perbaiki layar Beranda yang sempat kosong — konten tampil lagi, bilah bawah tetap ramping di tengah.
- **v1.32.3** (14 Okt 2026): Tombol mata di kartu saldo berfungsi normal (toggle saja, posisi rapi di pojok kanan).
- **v1.32.4** (14 Okt 2026): Tombol + duduk rapi di dalam kapsul bilah bawah — teks layar tidak lagi tertutup.
- **v1.32.5** (14 Okt 2026): Bayangan bilah bawah lebih ramping — teks tetap jernih dibaca.
- **v1.32.6** (14 Okt 2026): Konten paling bawah terlihat sepenuhnya — adaptif navigasi gestur.
- **v1.28.0** (13 Okt 2026): Identitas visual baru — hero mesh cair ikut aksen, bottom bar melayang, tombol/chip pill, kartu + shadow lembut, overview Budget status mesh. Kontras putih ≥4.5:1 terukur 6 aksen × 2 tema. Logika/provider/query tidak berubah.
- **v1.27.1** (13 Okt 2026): Tombol Masuk di Beranda sebelum login — ketuk untuk buka Profil lalu masuk Google. Perbaiki jalan login yang tak terlihat saat logged-out.
- **v1.27.0** (13 Okt 2026): Profil + Keluarga mandiri — pohon akun Beranda → Profil → Keluarga; header avatar + sapaan setelah login (belum login = wordmark tetap); nama panggilan bisa diubah di Profil; Pengaturan jadi 4 grup. 5 regression test.

## Signing (sekali saja — sudah dilakukan 7 Okt 2026)
- Keystore: `android/app/mywallet.keystore` (RSA 2048, berlaku s.d. 1 Okt 2051).
- File ini **di-ignore git** dan hukumnya: **JANGAN sampai hilang**. Kalau keystore hilang/berganti, update aplikasi wajib uninstall dulu (tanda tangan beda = Android menolak update).
- Backup: `E:\dev\keys\mywallet.keystore` + password di `E:\dev\keys\mywallet-password.txt`.
- `android/key.properties` (di-ignore git) menunjuk ke keystore lokal.
- Build cloud membaca 4 secrets repo: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
- Fingerprint SHA256: `9E:9A:93:B6:C4:C8:1D:8B:AB:C1:A9:64:04:2D:7B:D0:3D:C1:91:AD:73:B3:59:B1:FE:68:29:37:4A:EC:73:05`
- `android/app/build.gradle.kts`: rilis pakai keystore sendiri kalau `key.properties` ada, kalau tidak fallback ke debug keys (biar `flutter run --release` tetap jalan di laptop).

## Cara merilis versi baru
1. Naikkan `version:` di `pubspec.yaml` (contoh: `1.0.1+2`).
2. WAJIB tambah entri baru paling atas di `lib/ui/changelog.dart` (satu-satunya sumber changelog in-app — dialog Tentang ambil dari sini otomatis). `test/changelog_test.dart` gagal bila langkah ini lupa.
3. Update `docs/07-Rilis-dan-Obtainium.md` (riwayat rilis) + `README.md` (status versi).
4. Commit + push ke `main` (tidak memicu workflow — hemat menit).
5. `git tag v1.0.1 && git push origin v1.0.1`
6. Workflow **Release MyWallet** otomatis jalan SEKALI: codegen → analyze → test → `flutter build apk --release` (signed) + AAB → membuat GitHub Release berisi `mywallet-v1.0.1.apk` (+ `.aab` untuk Play Console).
7. Pantau di tab **Actions → Release MyWallet**.

## Workflow CI (3 file di `.github/workflows/`)

| Workflow | Pemicu | Hasil |
|---|---|---|
| **Check MyWallet** (`build.yml`) | PR ke `main` / manual | Analyze + test saja (gerbang review; push ke `main` tidak memicu) |
| **Fast Flutter APK Build** (`build-apk.yml`) | manual | APK rilis signed keystore resmi (artifact, retensi 3 hari) — buat cek cepat di HP tanpa tag |
| **Release MyWallet** (`release.yml`) | push tag `v*` / manual | Analyze + test + GitHub Release berisi `mywallet-vX.Y.Z.apk` + `.aab` → Obtainium |

## Riwayat rilis
- **v1.26.0** (12 Okt 2026): Menu fitur Beranda + nav ramping + scan struk resmi dibuka. Full 227/227.
- **v1.25.1** (12 Okt 2026): Fix keyboard — input dompet tak lagi hilang saat keyboard muncul. Full 217/217.
- **v1.25.0** (12 Okt 2026): Dompet ganda + transfer — pemilih Beranda, Kelola, filter per-dompet, PDF ikut filter, sync akun. Full 215/215.
- **v1.24.11** (12 Okt 2026): Laporan menjawab — selisih hero, wawasan vs bulan lalu, legenda + pie bernama. Full 190/190.
- **v1.24.10** (12 Okt 2026): Tile dua-baris + filter bottom-sheet — catatan lega, filter tanpa scroll. Full 182/182.
- **v1.24.9** (11 Okt 2026): Riwayat jujur penuh — search kategori+nominal, total jujur, pesan kosong adil. Full 178/178.
- **v1.24.8** (11 Okt 2026): Tombol header polos + Riwayat menjawab — total hasil, grup tanggal, Semua jujur. Full 171/171.
- **v1.24.7** (11 Okt 2026): Unifikasi desain global — jarak, tombol, header satu bahasa. Full 167/167.
- **v1.24.6** (11 Okt 2026): Header wordmark + gear — baris atas Beranda rapi sejajar. Full 167/167.
- **v1.24.5** (11 Okt 2026): Nominal rata kanan + strip ringkas — angka sejajar, ringkasan satu baris. Full 166/166.
- **v1.24.4** (11 Okt 2026): List rapi + logo baru — tanggal tidak diulang per baris, logo bg-white. Full 164/164.
- **v1.24.3** (11 Okt 2026): Brutal-polish Beranda — tombol utama menonjol, link spesifik, monthnav selaras. Full 163/163.
- **v1.24.2** (11 Okt 2026): Polish B2C Beranda — spacing lega via token, kartu jelas di mode gelap, tombol mata 44px. Full 163/163.
- **v1.24.1** (11 Okt 2026): Fix kontras tombol Beranda mode gelap — teks kini jelas terbaca. Full 163/163.
- **v1.24.0** (11 Okt 2026): Beranda B2C minimalis — kartu putih bersih, saldo besar, 1 CTA. Full 163/163.
- **v1.22.0** (11 Okt 2026): Redesign Beranda editorial + logo baru. Hero ledger full-bleed, strip delta ringkas. Full 163/163.
- **v1.21.1** (10 Okt 2026): Audit referensi Beranda — haptic semua tombol (banner + kartu utang). Isi/data nol berubah. Full 163/163.
- **v1.21.0** (10 Okt 2026): Beranda papan kemenangan — saldo count-up, pacing budget di kartu utama, streak harian + misi, Catat Kilat (form terisi). Fix 3 bug visual QA golden. Full 163/163.
- **v1.20.0** (10 Okt 2026): B2C total semua halaman — kartu terangkat lembut, empty-state medali, daftar stagger halus, haptic global, transisi fade-through. Isi/data nol berubah. Full 160/160.
- **v1.19.1** (10 Okt 2026): Kelola anggota — baris Anggota bisa diketik (bottom sheet peran/keluarkan/keluar + konfirmasi), tombol Keluar utama pakai dialog + peringatan pengelola-terakhir. Rules kick owner. Full 160/160.
- **v1.19.0** (10 Okt 2026): Sync beta serumah — push/pull transaksi + kategori via tombol Sync data di Keluarga (LWW updatedAt, categoryUuid resolve, skip cermin utang, hapus merambat). Full 157/157. WAJIB publish firestore.rules baru.
- **v1.18.1** (10 Okt 2026): Audit screenshot ReWin — pisah pesan timeout/deadline ("sinyal lemot, pindah jaringan") dari tanpa-internet, copy UI preemptif jujur "tanpa sinyal". Full 148/148.
- **v1.18.0** (10 Okt 2026): Keluarga production-grade + sapaan waktu — tombol mati preemptif saat offline, nama max 40 + counter, daftar anggota, share invite WA, guard owner putar kode, sapaan `Selamat pagi/siang/sore/malam` + nama akun. Full 147/147.
- **v1.17.4** (10 Okt 2026): Audit login — timeout berlapis `signIn()` (Google 60/Firebase 45/store 20 dtk) + fallback signedIn, fix join baca nama dari dokumen invite, `householdName` di invite buat/putar, pesan `permission-denied` jujur. Test timeout + permission baru, full 131/131.
- **v1.17.3** (10 Okt 2026): Fix halaman Keluarga macet di skeleton loading — `boot()` timeout 8 detik (silent-login + baca server), fallback personal/signedIn, tombol login tetap bisa ditekan manual. Test `family_ux_test.dart` (+bootTimeout), full 128/128.
- **v1.17.2** (10 Okt 2026): Konfigurasi login Google lengkap — `google-services.json` baru (3 oauth client termasuk web type-3), secret CI diperbarui, tanpa perubahan kode. Full 127/127.
- **v1.17.1** (10 Okt 2026): Rapikan halaman Keluarga — hero empty-state (manfaat + tombol Google besar), error tampil inline kontras-tinggi + tombol Coba lagi (bukan snackbar samar), pesan login jujur (config SHA-1/OAuth, provider nonaktif). `AuthService` null-safe tanpa Firebase init, test `family_ux_test.dart`, full 127/127.
- **v1.17.0** (10 Okt 2026): Keluarga Fase 1 — login Google + buat/gabung rumah tangga + kode invite 24 jam (`household.dart` murni, `auth_service.dart`, `settings_family.dart`, `firestore.rules` anggota-only). Opt-in: tanpa login = offline 100% seperti sebelumnya. Test `household_test.dart` 14 kasus, full 122/122. Sync data Fase 2.
- **v1.16.2** (10 Okt 2026): Fix restore/wipe database (`Bad state connection closed`): path DB tanpa query, WAL checkpoint sebelum backup, validasi header SQLite. Test `backup_file_test.dart` 9 kasus. Restore v1.16.0 → v1.16.1+ jalan.
- **v1.16.1** (10 Okt 2026): Ganti package Android → `com.rezal.mywallet` + wiring Firebase Fase 1 (project `mywallet-7614d`): plugin google-services 4.5.0, `firebase_core` init aman-gagal, paket auth/firestore/google_sign_in v7, minSdk 23, secrets CI. CATATAN: install sebagai app baru — backup dulu via Kelola.
- **v1.16.0** (10 Okt 2026): Fondasi sync-ready Fase 0 (tetap 100% offline, tanpa network) — skema DB v3: `uuid/updatedAt/deletedAt/householdId` di 5 tabel + `categoryUuid` di transactions, migrasi v2→v3 aman + backfill otomatis, semua query siap soft-delete, `actions`/`debt_actions` bump `updatedAt`. Persiapan Google Sign-In + Firestore (Fase 1-2: auth + household + sync engine).
- **v1.15.0** (9 Okt 2026): Manajer utang-piutang (100% offline) — tab Utang ke-5 + kartu ringkas Beranda (sisa utang vs piutang, tap → Kelola). Utang = pinjam (catat = pemasukan, bayar = pengeluaran), Piutang = meminjami (catat = pengeluaran, terima = pemasukan); tiap aksi menulis transaksi cermin otomatis sehingga saldo, laporan, riwayat, PDF & CSV ikut tanpa ubah query lama. Cicilan parsial + anti-overpay + jatuh tempo + progress + lunas otomatis. Skema DB v2 (migrasi v1→v2 aman).
- **v1.14.0** (8 Okt 2026): Export PDF laporan + Scan struk (100% offline) — tombol PDF di Laporan & Kelola (ringkasan + rincian kategori % + daftar transaksi, share/simpan file, tanpa server); tombol scan di form Catat (kamera/galeri → ML Kit on-device → prefill nominal/tanggal/warung/kategori, user cek + Simpan manual); izin kamera baru. Logika simpan/transaksi tidak berubah.
- **v1.13.1** (8 Okt 2026): Samakan Beranda dengan mockup ala GoPay (visual saja) — sapaan personal “Hai, {nama}!” + setting Nama sapaan, label “SALDO MYWALLET”, nav bulan disembunyikan di tampilan default, aksi cepat 4 chip, tile Masuk OKT / Keluar OKT / SISA BUDGET, ringkasan harian pindah ke seksi aktivitas, kartu saldo dijenuhkan (+35%) selaras seed mockup dengan kontras putih ≥4.5:1. Logika/provider/query tidak berubah.
- **v1.13.0** (8 Okt 2026): Beranda pola GoPay (visual saja) — kepala sapaan berwarna aksen + kartu saldo gradien ikut warna tema + aksi cepat + banner insight (delta/pacing/CTA) + tile metrik; kontras putih ≥4.5:1 di 48 pengukuran (6 aksen × 2 tema × kartu/kepala). Logika/provider/query/navigasi tidak berubah.
- **v1.12.1** (8 Okt 2026): Polish Beranda — semantik nominal satu sumber (`AppColors` income/expense + varian hero, kontras WCAG ≥4.5:1), delta % via provider, CTA "Atur budget" saat kosong, strip hari ini jelas saat nol, hero berboder dark mode, golden test Beranda + README landing page. Logika/provider/query/navigasi tidak berubah.
- **v1.12.0** (8 Okt 2026): Beranda Insight (visual saja) — header sapaan pinned, hero netral + arus semantik + delta vs bulan lalu + pacing budget, kategori proporsional + persen, strip hari ini ringkas, riwayat tergrup + chevron, navigasi M3 NavigationBar, skeleton shimmer + error ramah semua layar, shared AppHeader/AppMonthNav, token bottomPad/touchMin. Logika/provider/query/navigasi tidak berubah.
- **v1.11.0** (8 Okt 2026): Logo MyWallet + Micro-UX premium — FAB Container Transform jadi form Catat, nominal autofocus + quick-add chips, haptic FAB/kategori/simpan, empty state memotivasi, nama aplikasi MyWallet. Logika/provider/query/navigasi tidak berubah.
- **v1.10.2** (8 Okt 2026): Fix bar bawah (visual saja) — blok hitam belang hilang + notch FAB rapat via `extendBody` + buang SafeArea pembungkus. Logika/provider/query/navigasi tidak berubah.
- **v1.10.1** (8 Okt 2026): Penyeragaman (visual saja) — FAB Catat tertanam via notch + Beranda satu-sliver-per-section + ikon monochrome di semua layar. Logika/provider/query/navigasi tidak berubah.
- **v1.10.0** (8 Okt 2026): Beranda baru (visual saja) — kartu saldo aksen + teks putih, progress bertrack abu terang, nama kategori lebih besar, ikon monochrome aksen, teks transaksi kontras, tombol Catat jadi FAB melayang. Logika/provider/query/navigasi tidak berubah.
- **v1.9.0** (7 Okt 2026): Redesign STEP 4 (visual saja) — Kategori + Pengaturan + Lock Screen baru, satu bahasa dengan STEP 1-3. Logika/provider/query/navigasi tidak berubah.
- **v1.8.0** (7 Okt 2026): Budget P0+P1 — dialog edit beneran (prefill + kategori dikunci) + hapus konfirmasi + undo 5 detik + validasi inline + kategori bottom sheet + overview "X dari Y aman" + urutan stabil + 6 test budget in-memory. Logika simpan/hitung tidak berubah.
- **v1.7.2** (7 Okt 2026): Fix list tetap "Belum ada budget" setelah simpan — trigger `budgetsProvider` dengarkan tabel budgets + transactions + SnackBar "Budget tersimpan.".
- **v1.7.1** (7 Okt 2026): Fix tombol Tambah Budget — dialog terbuka instan (kategori dimuat di dalam dialog) + SnackBar bila belum lengkap.
- **v1.7.0** (7 Okt 2026): Redesign STEP 3 (visual saja) — navigasi bawah custom + Budget baru (overview + item + progress) + Laporan baru (ringkasan + bar 6 bulan + pie + rincian). Logika/provider/query tidak berubah.
- **v1.6.0** (7 Okt 2026): Redesign STEP 2 (visual saja) — Riwayat baru (header custom, bulan ala Beranda, chip filter kompak) + Form Transaksi baru (nominal hero, kategori bottom sheet, tanggal tile, Simpan 52px). Logika/provider/query tidak berubah.
- **v1.5.0** (7 Okt 2026): Redesign STEP 1 ala shadcn (visual saja) — design tokens + TxTile baris bersih + Beranda baru (header custom, saldo kartu subtle) + tema netral restrained. Logika/provider/query tidak berubah.
- **v1.4.0** (7 Okt 2026): Pengaturan multi-halaman (hub + 4 sub-halaman + cari global) + input nominal otomatis bertitik + border input seragam via tema.
- **v1.3.0** (7 Okt 2026): Restruktur Pengaturan (kolom cari, 4 grup, Isi Beranda sub-bagian, Kelola kategori halaman sendiri, hirarki Data, Tentang tap-to-copy + changelog) + ringkasan harian di Beranda + warna semantik ikut colorScheme (pemasukan = primary, keluar = error, warning 80% = tertiary) + palet pie tanpa hijau.
- **v1.2.0** (7 Okt 2026): Tampilan full — warna aksen (6) + Material You + hitam pekat + privacy semua nominal + nominal ringkas + kustom Beranda + overkill (font/list/tanggal/ikon).
- **v1.1.0** (7 Okt 2026): P0 Pengaturan (tema, sembunyikan saldo, saldo awal, kunci PIN/biometrik, pengingat harian, backup/restore/hapus data) + bottom bar [home][history][+][budget][laporan] + settings pindah ke kanan atas Beranda.
- **v1.0.1** (7 Okt 2026): fix saldo reaktif (dulu `FutureProvider`, sekarang `StreamProvider`), total & grafik ikut ganti bulan, riwayat filter per bulan.
- **v1.0.0** (7 Okt 2026): MVP awal.

## Pasang di HP via Obtainium
1. Install Obtainium (dari F-Droid / GitHub).
2. Obtainium → **+ Add App** → sumber **GitHub** → tempel `https://github.com/Mighty-Nievl/MyWallet` (atau URL halaman Releases-nya).
3. Karena repo masih **private**, pilih salah satu:
   - **Jadikan repo public** — paling gampang, kode tidak berisi rahasia apa pun (keystore & password tidak ikut ke-push), atau
   - Masukkan GitHub Personal Access Token (akses baca repo ini) ke pengaturan sumber GitHub di Obtainium.
4. Install → izinkan "Install unknown apps" untuk Obtainium (sekali saja).
5. Tiap ada rilis baru → muncul notifikasi update otomatis. 🎉
