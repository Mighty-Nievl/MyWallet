# 02 — Arsitektur

## Stack
- **Flutter 3.44** (Dart 3.12) · Material 3 · `com.rezal.mywallet`
- **Firebase (Fase 1+, opt-in)** → `firebase_core` init aman-gagal di `main.dart` (tanpa config = offline murni); `firebase_auth` + `google_sign_in` v7 (`initialize` sekali → `authenticate()` → `idToken` → `GoogleAuthProvider.credential`) + `cloud_firestore` (`asia-southeast2`). Config `android/app/google-services.json` di-gitignore, CI via secret `GOOGLE_SERVICES_JSON_BASE64`. Package name didaftarkan ke Firebase = `com.rezal.mywallet` (project `mywallet-7614d`).
- **Drift 2.35** + `sqlite3_flutter_libs` → SQLite lokal (`mywallet.sqlite`)
- **flutter_riverpod 3.4** → state reaktif. Catatan penting: `StateProvider` di v3 pindah ke `package:flutter_riverpod/legacy.dart` — jangan lupa import itu kalau pakai `StateProvider`.
- **fl_chart** → grafik laporan · **shared_preferences** → pengaturan · **share_plus** (v12 API: `SharePlus.instance.share(ShareParams(...))`) + **csv** (v8 API: `Csv().encode(rows)`) → export CSV.
- **local_auth** → kunci biometrik (butuh `FlutterFragmentActivity` di `MainActivity.kt`) · **flutter_secure_storage** → simpan hash PIN · **flutter_local_notifications** + **timezone** + **flutter_timezone** → pengingat harian terjadwal · **file_picker** (v13 federated API: `saveFile(fileName:, bytes:)` → `Uri?`, `pickFiles` → list) + **share_plus** (v13 API: `SharePlus.instance.share(ShareParams(...))`) + **csv** (v8 API: `Csv().encode(rows)`) → export CSV · **package_info_plus** → versi aplikasi otomatis di layar Tentang · **dynamic_color** → Material You (ikuti wallpaper HP).
- Codegen: `build_runner` + `drift_dev` → `lib/data/database.g.dart` (jangan edit manual).

## Struktur folder

```
lib/
├── main.dart            # ProviderScope + MyWalletApp + pulihkan jadwal pengingat
├── data/
│   ├── tables.dart      # definisi tabel + seed kategori
│   ├── database.dart    # AppDatabase + query custom (saldo, total, riwayat, per-kategori)
│   ├── database.g.dart  # hasil codegen (jangan edit)
│   ├── providers.dart   # Riverpod: db, kategori, saldo, bulan, riwayat, budget
│   ├── actions.dart     # fungsi tulis: tambah/edit/hapus transaksi, kategori, budget
│   ├── settings.dart    # semua pengaturan + providers (tema, privacy, aksen, font, beranda, list)
│   ├── lock_service.dart     # hash PIN (secure storage) + biometrik
│   ├── reminder_service.dart # notifikasi harian terjadwal
│   └── backup_service.dart   # VACUUM INTO backup, restore, wipe (+ PRAGMA database_list)
└── ui/
    ├── app.dart         # MaterialApp + DynamicColorBuilder + tema + font scale + gerbang LockScreen
    ├── app_theme.dart   # Material 3: 6 aksen + true black + compact + fromScheme dinamis
    ├── display.dart     # DisplayPrefs: money()/signed()/date() sesuai privacy + gaya
    ├── shell.dart       # 4 tab + tombol + tengah [home][history][+][budget][laporan]
    ├── format.dart      # formatRp, formatRpCompact (Rp1,5 jt), formatDate(Relative), monthKey/Label/shift
    ├── widgets/tx_tile.dart  # ikut DisplayPrefs (ikon/date/nominal)
    └── screens/         # home, tx_form, history, budget, reports, settings, lock
```

## Alur data
1. UI membaca **provider** (`watch`) → rebuild otomatis saat DB berubah (stream).
2. UI menulis lewat **actions** (`addTransaction`, `upsertBudget`, …) → Drift insert/update/delete.
3. Tidak ada repository layer terpisah — `database.dart` + `providers.dart` + `actions.dart` menjalankan peran itu, cukup untuk skala MVP.

## Konvensi
- Nominal = `int` rupiah (tanpa desimal), kolom `amount`.
- `isExpense`: `true` = keluar, `false` = masuk.
- Bulan = string `"yyyy-MM"` (`selectedMonthProvider`), rentang dihitung di `monthRangeProvider`.
- Kategori nullable di transaksi → tampil "Tanpa kategori".
