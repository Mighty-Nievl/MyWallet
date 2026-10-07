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
2. Commit + push ke `main`.
3. `git tag v1.0.1 && git push origin v1.0.1`
4. Workflow **Release MyWallet** otomatis jalan: codegen → analyze → test → `flutter build apk --release` (signed) + AAB → membuat GitHub Release berisi `mywallet-v1.0.1.apk` (+ `.aab` untuk Play Console).
5. Pantau di tab **Actions → Release MyWallet**.

## Riwayat rilis
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
