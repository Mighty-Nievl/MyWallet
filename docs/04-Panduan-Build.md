# 04 — Panduan Build

## Syarat
- Flutter 3.44 (di `E:\dev\flutter`), JDK 17, Android SDK di `E:\dev\android\sdk` (platform 35/36 + build-tools sudah ada).
- Config Flutter yang sudah diset di mesin ini:
  - `flutter config --android-sdk "E:/dev/android/sdk"`
  - `flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"`

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
