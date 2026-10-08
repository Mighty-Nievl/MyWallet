# 07 — Rilis & Install via Obtainium

## Kenapa GitHub Releases?
Obtainium (updater open-source di HP) memantau halaman **GitHub Releases**, bukan Actions artifacts. Jadi tiap versi stabil diterbitkan sebagai Release berisi APK bertanda tangan → HP dapat notifikasi update otomatis.

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
4. Commit + push ke `main`.
5. `git tag v1.0.1 && git push origin v1.0.1`
6. Workflow **Release MyWallet** otomatis jalan: codegen → analyze → test → `flutter build apk --release` (signed) + AAB → membuat GitHub Release berisi `mywallet-v1.0.1.apk` (+ `.aab` untuk Play Console).
7. Pantau di tab **Actions → Release MyWallet**.

## Riwayat rilis
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
