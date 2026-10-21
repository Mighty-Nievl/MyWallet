# 04 — Panduan Build

## Cara utama: GitHub Actions (cloud, tanpa makan RAM lokal)
Repo: `Mighty-Nievl/MyWallet` (publik). Sejak v1.36.0 push ke `main` **tidak memicu workflow apa pun** (dulu tiap commit = analyze + test + APK debug = boros menit). Sekarang:
- **Cek cepat (tanpa rilis):** PR ke `main`, atau manual via **Actions → Check MyWallet → Run workflow** → job `analyze-test`: pub get → build_runner → `flutter analyze` → `flutter test`.
- **APK signed buat dites di HP tanpa tag:** manual via **Actions → Fast Flutter APK Build → Run workflow** → artifact `mywallet-apk-release` (retensi 3 hari).
- **Rilis resmi:** push tag `v*` → `release.yml` jalan sekali: analyze → test → APK rilis signed + AAB → GitHub Release. AAB untuk Play Console cuma ada di sini (sejak v1.33.0 AAB tidak dibuat di alur cek biasa).
- Prep Android (disk, Java, Flutter, tuning Gradle, NDK anti-korup, keystore, `google-services.json`) ada di satu composite action: `.github/actions/android-prep` — dipakai ketiga workflow, jangan disalin lagi.
- ✅ Build pertama (7 Okt 2026, run `37568474280`): hijau semua — `analyze-test` 42 dtk, `build-android` 10 mnt 46 dtk. Artifact: `app-release.aab` 58 MB, `app-debug.apk` 164 MB (tersimpan di `dist-cloud/`, di-ignore git).

## Rilis resmi ke GitHub Releases (untuk Obtainium)
Lihat [[07-Rilis-dan-Obtainium]] — ringkasnya: naikkan `version:` di `pubspec.yaml`, push, lalu `git tag vX.Y.Z && git push origin vX.Y.Z`. Workflow **Release MyWallet** membangun APK rilis bertanda tangan + AAB lalu menerbitkannya ke halaman Releases.

## Syarat
- Flutter 3.44 (di `E:\dev\flutter`), JDK 17, Android SDK di `E:\dev\android\sdk` (platform 35/36 + build-tools sudah ada).
- Config Flutter yang sudah diset di mesin ini:
  - `flutter config --android-sdk "E:/dev/android/sdk"`
  - `flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"`

## Secrets CI (Firebase + keystore)

File rahasia JANGAN di-commit (lihat `.gitignore` + `android/.gitignore`):

| File lokal | Secret GitHub | Isi |
|---|---|---|
| `android/app/google-services.json` | `GOOGLE_SERVICES_JSON_BASE64` | base64 file dari Firebase Console (project `mywallet-7614d`, app `com.rezal.mywallet`) |
| `android/app/mywallet.keystore` | `KEYSTORE_BASE64` | base64 keystore rilis |
| `android/key.properties` | `KEYSTORE_PASSWORD` / `KEY_PASSWORD` / `KEY_ALIAS` | password + alias |

Generate base64 (dari root repo, git-bash):

```bash
base64 -w0 android/app/google-services.json
```

Tempel hasilnya ke GitHub → Settings → Secrets and variables → Actions → New repository secret.
Tanpa `GOOGLE_SERVICES_JSON_BASE64`, job `build-android`/`release` gagal cepat di step "Siapkan google-services.json" (plugin `com.google.gms.google-services` butuh file itu saat build Android).

## Perintah (dari `E:\Projects\MyWallet`)

```powershell
flutter pub get
dart run build_runner build              # regenerasi database.g.dart (wajib tiap ubah tables.dart/database.dart)
flutter analyze                          # harus: No issues found
flutter test                             # 12 test helper format
flutter build apk --debug                # APK: build\app\outputs\flutter-apk\app-debug.apk
flutter install                          # install ke HP/emulator yang tersambung
flutter run                              # jalan + hot reload (Windows desktop juga bisa: flutter run -d windows)
```

## Catatan build
- `flutter build apk --debug` pertama kali mengunduh Gradle + dependencies Android — butuh internet & waktu beberapa menit.
- Kalau build Android gagal dengan error Java: pastikan JDK 17 yang dipakai (`flutter doctor` → Android toolchain harus ✅).
- `database.g.dart` JANGAN diedit manual — selalu hasilkan ulang via build_runner.
- **Mode hemat RAM (2GB):** `android/gradle.properties` sudah diset `-Xmx2g`, 1 worker, tanpa parallel, Kotlin in-process. Build lebih lambat (±5-8 menit) tapi aman di RAM kecil. Setelah ubah file itu, daemon lama harus dimatikan (`gradle --stop`) agar setting kepakai.

## Kecepatan build (kenapa cloud ±10 menit, lokal bisa <30 detik?)
Tiga jenis build yang beda obat:
- **Cloud (GitHub Actions) = selalu dingin.** Tiap run sewa VM baru: unduh Flutter SDK + Gradle + dependencies Maven, compile Dart AOT + Kotlin + native (sqlite3), lalu build (push biasa = APK debug; rilis = APK + AAB). Normalnya 8–12 menit. Percepatan yang sudah dipasang di workflow: cache pub + cache Gradle, setting Gradle kencang khusus CI (`-Xmx4g`, 4 worker, parallel + caching + incremental — `android/gradle.properties` 2GB di repo di-timpa di CI karena itu yang bikin cloud ikut lambat), dan `cancel-in-progress` biar push baru membatalkan build basi. Ekspektasi realistis: run pertama setelah ini masih dingin (±10 menit, cache belum ada), run berikutnya ±5–7 menit. **30 detik tidak mungkin** untuk build rilis bersih di cloud.
- **Lokal full build (`flutter build apk`) = menit.** Sama seperti cloud tapi cache panas (Gradle + pub sudah ada) → 1–3 menit. Setting 2GB di repo memang bikin ini lebih lambat demi RAM.
- **Lokal dev (`flutter run` + hot reload) = detik.** Ini yang <30 detik: `flutter run -d windows` / ke HP, ubah kode, tekan `r` (reload) / `R` (restart). Full build ulang hanya saat butuh file APK/AAB — sehari-hari pakai Obtainium/cloud saja.
