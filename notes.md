# Review UI/UX Beranda (Home)

Tanggal: 2026-10-22 · Versi yang di-review: v1.36.2 · Commit `a516bb5`

## Verdict

**7/10.** Identitas visual sudah matang, tapi Beranda sekarang kelebihan beban:
Beranda mencoba jadi tiga halaman sekaligus (kartu saldo, dashboard insight, menu
navigasi), sehingga tidak ada yang benar-benar unggul. Yang paling penting —
transaksi terakhir — justru ada di bawah lipatan layar.

## Yang sudah bagus

- **Kartu saldo = fokus yang jelas.** Kontras tinggi, nominal besar, mesh hijau
  terasa premium, mata toggle rapi. Hierarki utama jelas tanpa perlu ditebak.
- **Grid aksi membedakan aksi vs navigasi.** Lingkaran isi warna (aksi) vs ikon
  outline (pintasan) + label grup + hairline — bagus, tidak salah ketuk.
- **Token & state konsisten.** Spacing, tipografi, radius, skeleton, empty state,
  error state, kontras WCAG semuanya pakai token yang sama.
- **Detail yang tidak asal.** Semantics label (termasuk delta), status bar adaptif,
  haptic, `FittedBox` untuk nominal panjang. UI-nya dipikirkan, bukan tempelan.

## Masalah utama

### 1. First viewport tidak menampilkan transaksi apa pun

Urutan sekarang (`lib/ui/screens/home_screen.dart`):

```
header → carousel dompet → FlowCards → grid 8 tombol → kontrol periode
       → Pengeluaran (kategori) → Terakhir dicatat
```

Di layar 390×844, bagian "Pengeluaran" dan "Terakhir dicatat" praktis baru
tampil setelah scroll panjang: header ~88px + carousel 244px (188 tinggi +
dots) + FlowCards ~110px + grid 8 tombol ~226px + kontrol periode ~100px
≈ 790px sebelum isi konten pertama. Yang tampil di layar pertama hanya saldo,
2 angka ringkasan, 8 tombol, dan kontrol periode.

Untuk aplikasi catatan keuangan, transaksi terakhir adalah salah satu hal yang
paling sering dicari. Efeknya: Beranda terasa seperti halaman menu, bukan
halaman insight.

### 2. Konteks periode datang terlambat

`FlowCards` (`:115`) bergantung pada periode aktif, tapi switcher periode baru
muncul di `:135` — di bawah angkanya. Akibatnya user melihat "Pemasukan
Rp2.400.000" tanpa tahu itu harian/mingguan/bulanan/tahunan. Saldo di atasnya
adalah saldo total (point-in-time), sedangkan kartu di bawahnya period-scoped:
dua makna berbeda bersebelahan tanpa label pemisah.

### 3. Ringkasan "hari ini" tidak berlabel

`_DailyStrip` (`home_screen.dart:340`) hanya menampilkan
"Masuk … · Keluar …" tanpa kata "Hari ini". Karena di atasnya sudah ada
ringkasan periode, angka ini mudah salah dibaca sebagai angka yang sama.
Keduanya perlu label eksplisit "Hari ini", atau hapus — informasinya sudah tercakup
saat periode = Harian.

### 4. Tap kartu arus kas tidak menepati janji

Kedua kartu di `lib/ui/widgets/flow_cards.dart:144` membuka `HistoryScreen`
yang sama, tanpa filter tipe. User menekan "Pengeluaran" lalu melihat
pemasukan juga. Semantics-nya bahkan menandai "button: true" — jadi UI
berjanji bisa difilter tapi tidak.

### 5. Duplikasi navigasi

Ada 8 tombol di grid, bottom dock (Riwayat / Catat / Scan), plus "Semua
transaksi" dan "Semua kategori". Catat, Scan, dan Riwayat punya 2–3 pintu
masuk. "Catat masuk" + "Catat keluar" juga menduplikasi tombol + di dock
(form catat sudah punya pilihan tipe).

### 6. Carousel mencampur data dengan pengelolaan

Halaman "Kelola dompet" (`account_carousel.dart:379`) ikut jadi halaman
carousel, sementara filter dompet tetap mengikuti halaman sebelumnya — jadi
setelah menyetor ke "Kelola", konten di bawahnya masih milik dompet yang
sebelumnya. Selain itu:
- Dots kecil, hit area hanya 24px (di bawah standar 48px) dan tak ada
  affordance lain bahwa carousel bisa digeser.
- Tidak ada angka total gabungan. Kalau user punya >1 dompet, tidak ada satu
  pun tempat yang menampilkan total seluruh uang — padahal itu sering jadi
  angka terpenting.

### 7. Empty state belum mendidik

User baru melihat: saldo Rp0, dua kartu Rp0, 8 tombol, kontrol periode, dua
empty state (kategori + transaksi). Tidak ada satu pun CTA utama yang
menarik perhatian. Layar pertama harusnya jelas: "Catat pengeluaran
pertamamu" atau "Scan struk", dan section analitik bisa disembunyikan sampai
ada data.

### 8. Warna belum jadi bahasa yang konsisten

Hijau dipakai untuk: Pemasukan, Pindah dana, Scan struk, dan aksen primer
aplikasi. Merah untuk Pengeluaran. Akibatnya tiga lingkaran di grid terlihat
"positif" padahal fungsinya berbeda (transfer dan scan bukan pemasukan).
Semacamnya hijau/merah sebaiknya direservasi untuk arah uang; transfer dan
scan pakai netral atau brand accent yang berbeda.

## Perbaikan yang direkomendasikan

Prioritas (P0 = paling besar dampaknya):

1. **Pindahkan kontrol periode ke atas FlowCards** (atau ke bawah header),
   dan tambahkan periode pada judul/label kartu arus kas
   ("Arus kas · Oktober 2026"). Menghilangkan ambiguitas scope.
2. **Naikkan "Terakhir dicatat" ke atas grid & kategori** supaya data muncul
   di layar pertama. Urutan yang lebih sehat:
   `saldo → periode → arus kas → terakhir dicatat → kategori → pintasan`.
3. **Kurangi duplikasi tombol.** Pangkas grid jadi pintasan yang tidak ada
   di dock (Pindah dana, Budget, Laporan, Utang) dan/biarkan "Catat/Scan/
   Riwayat" hanya di dock. Kalau perlu buka "Catat masuk/keluar" lewat satu
   tombol Catat yang sudah ada.
4. **Kirim filter tipe saat tap FlowCards** — buka Riwayat dengan
   `isExpense` terisi sesuai kartu, dan tampilkan filter aktifnya.
5. **Berlabeli DailyStrip** ("Hari ini") atau hapus.
6. **Pisahkan "Kelola dompet" dari carousel** (pindahkan ke gear/menu
   header) dan pertimbangkan card/jumlah "Semua dompet" untuk total gabungan.
7. **Naikkan hit area dots** ke 48px + beri affordance geser (chevron/fade).
8. **Buat empty state onboarding** untuk user tanpa transaksi: satu CTA
   besar, section analitik disembunyikan sampai ada data.
9. **Rapikan semantik warna**: hijau/merah untuk arah uang, netral untuk
   transfer/scan.

## Catatan proses (QA visual)

- Golden `test/goldens/home_light.png` & `home_dark.png` **sudah ketinggalan** —
  belum memuat `FlowCards` sama sekali.
- Golden hanya dijalankan lokal lewat `--dart-define=GOLDEN=true`
  (`test/home_design_test.dart:36`); CI (Ubuntu/font DejaVu) melewat
  golden, jadi tidak ada jaring pengaman regresi visual di Beranda.
- Konsekuensinya: review ini bersumber dari struktur widget + golden lama,
  bukan perbandingan piksel current. Kalau mau pixel-perfect review, perlu
  screenshot dari build terbaru.
