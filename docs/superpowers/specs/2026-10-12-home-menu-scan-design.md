# Spec: Menu Fitur Beranda + Navigasi Bawah Baru (v1.26.0)

Tanggal: 12 Okt 2026. Status: disetujui user (chat 12 Okt 2026).

## 1. Latar + keputusan yang sudah dikunci

Beranda sekarang: hero saldo → strip dompet → nav bulan → Top kategori →
Terakhir dicatat. Navigasi bawah: 5 tab (Beranda/Riwayat/Budget/Laporan/Utang)
+ FAB `+` melayang (kanan bawah) buka form Catat. Mesin scan struk SUDAH ada
(`ReceiptScanService`: image_picker → ML Kit OCR on-device → `parseReceiptText`
→ `ReceiptDraft`; privasi aman, tak keluar HP) tapi belum punya pintu masuk
dari navigasi.

Keputusan user (final, jangan dibuka lagi tanpa alasan baru):

1. Menu Beranda = **C campuran + pemisah**: aksi cepat dan jalan pintas dalam
   satu grid, dipisah sekat + label grup + beda gaya tombol.
2. Tab kegusur = **A pindah ke menu fitur**: Riwayat/Budget/Laporan/Utang
   dijangkau lewat grid Beranda. Beranda jadi pintu masuk semua.
3. Tombol Catat tengah = **B menonjol**: lingkaran solid besar di tengah bar,
   bukan tab rata.
4. Scan = **B terus C**: sheet pilihan (kamera/galeri) → halaman pratinjau
   hasil (koreksi → simpan).
5. Grid = **B 8 item** (4 aksi + 4 pintas), 4 kolom × 2 baris.
6. Tambahan disetujui: label grup "Aksi cepat / Lihat" + FAB lama dihapus
   (fungsinya pindah ke tombol tengah, tanpa pintu catat ganda).

## 2. Komponen 1 — Grid menu Beranda (`home:features`)

Posisi: SliverToBoxAdapter di bawah strip dompet (`home:accounts`), di atas
nav bulan (`home:monthnav`). Ini slot aksi jatah hero, BUKAN blok baru di
kontrak Beranda (kontrak 4 blok v1.24.x tetap; grid = isi slot aksi).

Isi (4 kolom × 2 baris, urutan tetap):

- Baris 1 "Aksi cepat": Catat masuk (+, hijau) · Catat keluar (−, merah) ·
  Pindah dana (⇄) · Scan struk (📷 ikon kamera outline).
- Baris 2 "Lihat": Riwayat · Budget · Laporan · Utang.

Pemisah tiga lapis (alasan: aksi mengubah data sekali tap, pintas cuma pindah
halaman — tampil identik = salah tap): label grup kecil di atas tiap baris,
sekat hairline antar baris, beda gaya tombol (aksi = ikon dalam lingkaran isi
warna tegas; pintas = ikon outline polos tenang). Tiap tile ≥48px sentuh
(token `touchMin`), spacing ikut token (`sectionGapLarge`, tanpa literal).

Wiring (pakai yang sudah ada, tanpa mesin baru):

- Catat masuk/keluar → `TxFormScreen(startAsExpense: false/true)` (param
  sudah ada, tinggal pakai).
- Pindah dana → `TransferSheet.show` yang sudah ada.
- Scan struk → alur scan §4 (sama persis dengan tab Scan bawah).
- Riwayat/Budget/Laporan/Utang → push halaman langsung (bukan `onGoTab`
  indeks lama — indeks tab berubah, lihat §3).

Grid ikut dompet aktif (`selectedAccountProvider`): catat/transfer/scan hasil
masuk dompet yang kepilih di strip atasnya. Dompet sendiri TIDAK jadi item
grid (chip-nya sudah ada di atas).

## 3. Komponen 2 — Navigasi bawah 3 tombol

Bentuk: `[Beranda] [ (＋) ] [Scan]`.

- Beranda (kiri) + Scan (kanan): destinasi M3 standar (ikon outline/penuh
  ikut tab aktif).
- Tengah: tombol lingkaran solid warna primer ±64px, overlap naik ~16px di
  atas bar, ikon `+` 28px. Tap = haptic + buka form Catat via transisi
  `OpenContainer` yang sekarang dipakai FAB (pemicu pindah, bukan mesin baru).
- FAB lama (`endFloat`) DIHAPUS di commit yang sama (tanpa periode ganda).
- Tab Riwayat/Budget/Laporan/Utang hilang dari bar. `onGoTab` lama
  (`home_screen.dart:135/156`, indeks 1/3) dimigrasi jadi push halaman
  langsung; `shell.dart` (_go/IndexedStack 5 layar) jadi 1 layar Beranda +
  state tab Scan (Scan BUKAN halaman — tap Scan = buka alur §4).
- Pengaturan tetap di gear header, tidak ikut-ikutan.

## 4. Komponen 3 — Alur Scan Struk

Satu fungsi `_openScanFlow` dipakai dua pintu (tab Scan + item grid).

1. Bottom sheet "Scan struk": 2 opsi (Ambil foto / Pilih dari galeri),
   `showDragHandle: true`, ikut bahasa form catat.
2. OCR via `ReceiptScanService.scanFrom(source)` (mesin ada). Loading
   ditunjukkan selama OCR.
3. Halaman pratinjau (baru, `ScanPreviewScreen`): thumbnail foto kecil +
   nominal/kategori/tanggal/catatan terisi tebakan `ReceiptDraft` + banner
   jujur "Hasil tebakan — periksa dulu". Pencocokan kategori: nama saran →
   cocokkan nama kategori DB, tak ketemu = "Tanpa kategori". Simpan →
   `addTransaction` dengan `accountId` dompet aktif → toast "Tersimpan".

Error jujur (tanpa ngarang data):

- Platform tanpa ML Kit (desktop): tombol Scan tetap ada, tap = dialog
  "belum didukung di perangkat ini", bukan crash diam.
- OCR kosong/gagal (`ReceiptScanEmpty`/batal user): snackbar + fallback buka
  form kosong. Parser tak boleh ngarang nominal (aturan `receipt_parse` yang
  sudah ada).

## 5. Testing

- Grid: 8 item render + tap tiap aksi buka tujuan benar (catat tipe benar,
  transfer sheet muncul, scan sheet muncul, pintas push halaman benar).
- Tombol tengah: tap buka form catat.
- Scan: teks OCR palsu → sheet → pratinjau terisi → simpan masuk DB dompet
  aktif; kasus desktop-unsupported; kasus OCR kosong.
- Absence-test: 4 tab lama hilang dari bar; FAB lama hilang; pintu catat
  tunggal (satu `OpenContainer`).
- Golden Beranda regen + vision light/dark (slot baru di bawah hero).
- Full suite + analyze hijau (kontrak ship tetap).

## 6. Rilis

Ship sebagai **v1.26.0** (fitur baru) ikut checklist skill mywallet-development
(bump nama+build, changelog entry `breaking: null` di atas, mock cocok,
docs 4 file, golden+vision, commit→push→tag→CI→Published→Obtainium).

## 7. Di luar scope

OCR selain latin, ML Kit desktop, perubahan parser struk, sync utang/budget
(Fase 3 roadmap), ubah kontrak 4 blok Beranda selain slot aksi ini.
