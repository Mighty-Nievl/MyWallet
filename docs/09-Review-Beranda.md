# Review UI/UX Beranda (Home)

Tanggal: 2026-10-22 · Versi yang di-review: **v1.36.2** · Commit `a516bb5`

> Dokumen ini disimpan sebagai **catatan historis**, bukan deskripsi kode saat ini.
> Status tiap temuan sudah diperbarui terhadap **v1.38.0** (`aeacd89`).

## Status per v1.38.0

| # | Temuan (v1.36.2) | Status | Bukti |
|---|---|---|---|
| 1 | First viewport tanpa transaksi | **Sebagian** — urutan sudah diperbaiki v1.37 | `home_screen.dart:110→216` |
| 2 | Konteks periode datang terlambat | **Selesai** v1.37 | `home_screen.dart:132-145` |
| 3 | Ringkasan "hari ini" tanpa label | **Selesai** v1.37 | `home_screen.dart:383` |
| 4 | Tap kartu arus kas tanpa filter | **Selesai** v1.37 | `flow_cards.dart:63,83` |
| 5 | Duplikasi navigasi | **Selesai** v1.37 | `home_feature_grid.dart:43-70` |
| 6 | Carousel mencampur data & pengelolaan | **Selesai** v1.37.1 + v1.38.0 | `account_carousel.dart:92-110,231-271` |
| 7 | Empty state belum mendidik | **Selesai** v1.38.0 | `home_screen.dart:118-125,606-640` |
| 8 | Semantik warna belum konsisten | **Moot** — lingkaran berwarna sudah tidak ada | `home_feature_grid.dart:117` |

Rekomendasi #7 (hit area dots 48px) **ditolak secara sadar** di v1.37.1: slot 48px
merusak pitch (celah antar dot jadi 42px sehingga dua titik 6px terbaca nyasar).
Slot dipakai 28×32 — masih di atas minimum WCAG 2.2 AA (24×24). Rasionalnya
tertulis di `account_carousel.dart:159-164`.

---

## Verdict (asli, v1.36.2)

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

**Status v1.38.0: sebagian.** Urutan v1.37 sudah jadi
`hero → periode → arus kas → terakhir dicatat → kategori → pintasan`
(`home_screen.dart:110-216`), tapi biaya vertikal hero + periode masih membuat
"Terakhir dicatat" berpotensi di bawah lipatan 390×844. Belum diukur ulang di
build nyata — tidak ada SDK lokal.

Urutan lama (v1.36.2, `lib/ui/screens/home_screen.dart`):

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

**Status v1.38.0: selesai** (v1.37). `PeriodSwitcher` + `PeriodNav` sekarang
di atas `FlowCards`, satu sliver `home:monthnav` (`home_screen.dart:132-145`).

`FlowCards` (`:115`) bergantung pada periode aktif, tapi switcher periode baru
muncul di `:135` — di bawah angkanya. Akibatnya user melihat "Pemasukan
Rp2.400.000" tanpa tahu itu harian/mingguan/bulanan/tahunan. Saldo di atasnya
adalah saldo total (point-in-time), sedangkan kartu di bawahnya period-scoped:
dua makna berbeda bersebelahan tanpa label pemisah.

### 3. Ringkasan "hari ini" tidak berlabel

**Status v1.38.0: selesai.** Teks kini `'Hari ini · Masuk … · Keluar …'`
(`home_screen.dart:383`).

`_DailyStrip` (`home_screen.dart:340` di v1.36.2) hanya menampilkan
"Masuk … · Keluar …" tanpa kata "Hari ini". Karena di atasnya sudah ada
ringkasan periode, angka ini mudah salah dibaca sebagai angka yang sama.
Keduanya perlu label eksplisit "Hari ini", atau hapus — informasinya sudah tercakup
saat periode = Harian.

### 4. Tap kartu arus kas tidak menepati janji

**Status v1.38.0: selesai** (v1.37). Tap kartu mengisi `historyFilterProvider`
lebih dulu — `flow_cards.dart:63` (pemasukan) dan `:83` (pengeluaran).

Kedua kartu di `lib/ui/widgets/flow_cards.dart:144` membuka `HistoryScreen`
yang sama, tanpa filter tipe. User menekan "Pengeluaran" lalu melihat
pemasukan juga. Semantics-nya bahkan menandai "button: true" — jadi UI
berjanji bisa difilter tapi tidak.

### 5. Duplikasi navigasi

**Status v1.38.0: selesai** (v1.37). Grid tinggal 4 pintasan unik — Pindah dana,
Budget, Laporan, Utang (`home_feature_grid.dart:43,50,57,64`); Catat/Scan/Riwayat
hanya di dock.

Ada 8 tombol di grid, bottom dock (Riwayat / Catat / Scan), plus "Semua
transaksi" dan "Semua kategori". Catat, Scan, dan Riwayat punya 2–3 pintu
masuk. "Catat masuk" + "Catat keluar" juga menduplikasi tombol + di dock
(form catat sudah punya pilihan tipe).

### 6. Carousel mencampur data dengan pengelolaan

**Status v1.38.0: selesai.** "Kelola dompet" keluar dari halaman carousel dan
jadi `TextButton` di baris indikator (v1.37.1); halaman 0 kini kartu gabungan
"Semua dompet" (v1.38.0, `account_carousel.dart:92-110,231-271`) sehingga total
seluruh uang punya satu tempat. Keputusan lama yang **sengaja dipertahankan**:
filter dompet tidak ikut berubah saat geser ke halaman Kelola
(`account_carousel.dart:101,139-143`).

Halaman "Kelola dompet" (`account_carousel.dart:379` di v1.36.2) ikut jadi halaman
carousel, sementara filter dompet tetap mengikuti halaman sebelumnya — jadi
setelah menyetor ke "Kelola", konten di bawahnya masih milik dompet yang
sebelumnya. Selain itu:
- Dots kecil, hit area hanya 24px (di bawah standar 48px) dan tak ada
  affordance lain bahwa carousel bisa digeser.
- Tidak ada angka total gabungan. Kalau user punya >1 dompet, tidak ada satu
  pun tempat yang menampilkan total seluruh uang — padahal itu sering jadi
  angka terpenting.

### 7. Empty state belum mendidik

**Status v1.38.0: selesai.** `hasAnyTxProvider == false` mengganti seluruh blok
analitik dengan satu kartu CTA `_OnboardingStart` (`home_screen.dart:118-125`,
widget di `:606-640`).

User baru melihat: saldo Rp0, dua kartu Rp0, 8 tombol, kontrol periode, dua
empty state (kategori + transaksi). Tidak ada satu pun CTA utama yang
menarik perhatian. Layar pertama harusnya jelas: "Catat pengeluaran
pertamamu" atau "Scan struk", dan section analitik bisa disembunyikan sampai
ada data.

### 8. Warna belum jadi bahasa yang konsisten

**Status v1.38.0: moot.** Grid tidak lagi memakai lingkaran isi warna; pintasan
kini tile outline seragam (`home_feature_grid.dart:117` = `onSurfaceVariant`).
Masalah "tiga lingkaran terlihat positif" hilang bersama widget-nya, bukan
karena diwarnai ulang.

Hijau dipakai untuk: Pemasukan, Pindah dana, Scan struk, dan aksen primer
aplikasi. Merah untuk Pengeluaran. Akibatnya tiga lingkaran di grid terlihat
"positif" padahal fungsinya berbeda (transfer dan scan bukan pemasukan).
Semacamnya hijau/merah sebaiknya direservasi untuk arah uang; transfer dan
scan pakai netral atau brand accent yang berbeda.

## Perbaikan yang direkomendasikan (asli, v1.36.2)

Prioritas (P0 = paling besar dampaknya):

1. **Pindahkan kontrol periode ke atas FlowCards** — *selesai v1.37*.
2. **Naikkan "Terakhir dicatat" ke atas grid & kategori** — *selesai v1.37*.
3. **Kurangi duplikasi tombol** — *selesai v1.37*.
4. **Kirim filter tipe saat tap FlowCards** — *selesai v1.37*.
5. **Berlabeli DailyStrip ("Hari ini")** — *selesai v1.37*.
6. **Pisahkan "Kelola dompet" dari carousel + total gabungan** — *selesai v1.37.1/v1.38.0*.
7. **Naikkan hit area dots ke 48px + affordance geser** — *ditolak sadar* (rasional di `account_carousel.dart:159-164`); affordance geser belum ada.
8. **Empty state onboarding satu CTA** — *selesai v1.38.0*.
9. **Rapikan semantik warna** — *moot di grid*; warna aksen `primary` di alur
   Scan/Pindah dana masih dipakai apa adanya.

## Catatan proses (QA visual)

- Golden `test/goldens/home_light.png` & `home_dark.png` **sudah ketinggalan** —
  belum memuat `FlowCards` sama sekali.
- Golden hanya dijalankan lokal lewat `--dart-define=GOLDEN=true`
  (`test/home_design_test.dart:36`); CI (Ubuntu/font DejaVu) melewat
  golden, jadi tidak ada jaring pengaman regresi visual di Beranda.
- Konsekuensinya: review ini bersumber dari struktur widget + golden lama,
  bukan perbandingan piksel current. Kalau mau pixel-perfect review, perlu
  screenshot dari build terbaru.
- Sisa yang masih terbuka dari poin ini: regenerasi golden (butuh Flutter SDK +
  font Windows di mesin user) — dicatat di `docs/06-Roadmap.md`.
