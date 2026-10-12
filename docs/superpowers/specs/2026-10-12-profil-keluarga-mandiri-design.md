# Spec: Profil + Keluarga Mandiri (Opsi 1 — Pohon Akun)

Tanggal: 12 Okt 2026. Status: disetujui user (Opsi 1 full-ship autopilot).
Ringkasan pilihan: header kiri avatar+sapaan → Profil; kanan gear saja;
Profil (B: +nama panggilan lokal editable); Keluarga mandiri pintu B
(Profil → Keluarga). Ikon Keluarga di header (A awal) BATAL.

## 1. Konteks & masalah

- `SettingsScreen` hub campur akun + rumah (`_HubEntry('Keluarga', ...,
  keys: keluarga/family/sync/google/login)` → `_GroupKey.keluarga`).
- `FamilySettingsPage` (`settings_family.dart`, 1096 baris) campur sign-in
  Google + buat/gabung rumah + anggota + sync + search 2 grup.
- Header Beranda selalu wordmark `MyWallet` + gear, tak ikut status login.
- Nickname lokal SUDAH ADA (`SettingsKeys.displayName` +
  `displayNameProvider` + dialog `editDisplayName` di `settings_actions.dart`
  maxLength 20) tapi tersembunyi di Tampilan → Isi Beranda.
- Sapaan ikut waktu SUDAH ADA (`lib/ui/greeting.dart`: Pagi/Siang/Sore/Malam
  + `resolveGreetingName(manual→Google→null)`).
- Foto Google TIDAK tersedia: `photoURL` nol di `lib/`, `FamilySession` tanpa
  field foto, tanpa Storage. Avatar = inisial. Bukan bug, batasan.

## 2. Desain (Opsi 1 — Pohon Akun)

```
Beranda (header kiri) → Profil → Keluarga (mandiri)
Beranda (gear kanan)  → Pengaturan (tanpa Keluarga)
```

### Section 1 — Header Beranda (`home_screen.dart`)

- `personal` (belum login): TIDAK BERUBAH — wordmark `MyWallet` + gear.
  Kontrak `home_design_test` existing aman.
- `signedIn`/`household`: kiri = `CircleAvatar` 40px inisial (huruf pertama
  `resolveGreetingName`) + kolom 2 baris (sapaan kecil `greetingTitle` +
  nama tebal, ellipsis) dalam satu `InkWell` → push `ProfileScreen`.
  Kanan = gear saja, tidak berubah. `AppHeader` tak diubah (Beranda pakai
  header custom baru `_HomeIdentity`, 4 layar lain tetap `AppHeader`).
- Loading session: tampil wordmark dulu (jangan kedip avatar).

### Section 2 — Halaman Profil (baru `profile_screen.dart`)

- Avatar inisial 64px + displayName Google (read-only, label jujur
  "dari akun Google") + email.
- Baris "Nama panggilan" (trailing = nilai `displayNameProvider` /
  "Ikut akun") → dialog SAMA `editDisplayName` (maxLength 20, trim,
  `SettingsService.setDisplayName`, snackbar "Nama sapaan disimpan").
  Editable sesuai permintaan user — pakai ulang, bukan bikin baru.
- Baris "Keluarga" (subtitle = nama rumah / email / "Belum gabung") →
  push halaman Keluarga mandiri.
- Tombol Masuk/Keluar Google (reuse `svc.signIn`/`signOut` via `_run`
  inline sederhana). Tanpa login = tombol Masuk + teks offline-first.
- BackHeader "Profil". Gap `sectionGapLarge` 32. Nol literal baru.

### Section 3 — Halaman Keluarga mandiri (`family_screen.dart`)

- Pindah `settings_family.dart` → `family_screen.dart`, class
  `FamilyScreen` (alias `FamilySettingsPage` dihapus; update 2 import:
  `settings_screen.dart`, `family_ux_test.dart`).
- Search bar `Cari di Keluarga…` DIBUANG (audit B2C: 2 grup tak butuh search).
  `initialQuery`, `_searchCtrl`, `_q`, `_match` dihapus total.
- Gap antar grup 24 → `sectionGapLarge` 32. Literal dibersihkan:
  padding sheet `8,24` → token, `vertical: 3` → `s4`, bottom `96` → token,
  ikon share/copy `size: 20` → 20 tetap via token? (glyph ikut aturan:
  hit-area 48 sudah, glyph 20 cukup — catat, bukan breach).
- Kontras: spinner `Colors.white` (baris 1058) → `scheme.onPrimary`.
- Semua logika TETAP: hero personal, buat/gabung, invite, anggota, sync,
  error card long-press, dialog keluar berpengaman. Nol ubah service.

### Section 4 — Pengaturan (`settings_screen.dart`)

- Hapus: import `settings_family.dart`, `_GroupKey.keluarga`, hub entry
  Keluarga + search keys, baris UI Keluarga + divider-nya, `_openGroup`
  cabang keluarga, `_groupLabel`/`_groupIcon` cabang, `family` watch +
  `familySubtitle` (hanya dipakai baris Keluarga).
- Search hub tetap untuk 4 grup sisa. Absence-test mengunci.

## 3. Data flow

- Header/Profil baca `familySessionProvider` (stream) + `displayNameProvider`
  (future). Nickname tulis via `SettingsService.setDisplayName` → invalidate
  → header sapaan ikut berubah. Offline-first: tanpa login semua tetap
  personal, Keluarga mandiri tampil hero personal (bisa login dari sana).
- Nol tabel baru, nol rules baru, nol koleksi baru. SharedPrefs key lama
  `display_name` dipakai ulang.

## 4. Error handling

- Pola existing dipertahankan: `FamilyException` → kartu error inline +
  Coba lagi + long-press salin. Profil: sign-in gagal → snackbar ramah
  (bukan crash). Nickname kosong = valid (kembali ikut akun Google).

## 5. Testing

- Baru: header login tampil sapaan+avatar (override `familySessionProvider`
  + `displayNameProvider`), tap avatar → Profil; Profil nickname tap →
  dialog muncul, simpan → provider berubah; Profil baris Keluarga → push;
  hub Pengaturan absence `Keluarga` + absence search key; Keluarga mandiri
  tanpa search bar (absence `Cari di Keluarga`).
- Existing wajib hijau: `home_design_test` (header personal `MyWallet`),
  `family_ux_test` (hero personal — update import nama baru), full suite,
  `flutter analyze` nol issue. Golden regen bila header berubah piksel
  + vision light+dark.

## 6. Ship (mywallet-development checklist)

Bump patch + changelog top (`breaking: null`, user-text tanpa istilah
internal) + mock sinkron + docs 4 file + analyze + full test + golden +
commit→push→tag→pantau CI triple success→Published+aset→Obtainium refresh.

## 7. Self-review

- Placeholder: nol (semua file:baris terisi).
- Konsistensi: pintu tunggal Keluarga via Profil (grid Beranda tak disentuh,
  8 tile genap tetap); kanan header gear saja (A awal batal eksplisit).
- Scope: satu siklus (header+profil+keluarga+hub). Foto Google & ganti nama
  akun DIKECUALIKAN (batasan teknis, bukan scope).
- Ambigu: "ubah foto profil" diartikan avatar inisial + label jujur (tak janji upload). "Ganti nama" diartikan nickname lokal
  (tak sentuh nama Google).
