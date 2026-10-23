# 10 — Jurnal Rilis

> Catatan per rilis: **kenapa** perubahan ini ada, bukan cuma apa yang berubah.
> `[[07-Rilis-dan-Obtainium]]` menyimpan daftar satu baris untuk user;
> catatan di sini menyimpan alasan, bukti, dan trade-off untuk diri sendiri
> enam bulan kemudian. Ditulis tiap kali tag dibuat.

## v1.41.0 — 23 Okt 2026 — backup ikut setiap simpan

**Masalah.** Setelah mencatat transaksi, baris "Backup terakhir" tidak berubah —
user (dan aku) mengharapkan "Baru saja". Dua sebab: (1) jatah 20 jam membuat
backup hanya jalan sekali sehari, jadi salinan tidak pernah memuat catatan
terakhir; (2) nama file berjam-menit membuat lima simpan dalam sehari
menghabiskan seluruh rotasi 5 dan menghapus riwayat hari sebelumnya. Ada juga
jalur gagal senyap: `start` bisa berjalan sebelum koneksi DB membuka file, lalu
menyerah sampai resume berikutnya — hasilnya "Belum pernah" padahal app baru
dibuka.

**Yang dikerjakan.** `tx_form_screen` memanggil `runNow()` setelah simpan dan
setelah hapus (jatah 20 jam kini hanya untuk pemicu latar). Nama file jadi
`mywallet-auto-YYYYMMDD.sqlite` — satu file per hari, simpan berikutnya
menimpa, rotasi 5 = lima hari terakhir. `start` diberi satu kesempatan 400 ms
sebelum menyerah.

**Pelajaran.** "Backup terakhir" adalah janji tentang *data*, bukan tentang
*jadwal*. Label yang jujur harus bergerak setiap kali data berubah, bukan
setiap kali jam dinding berubah.

**Bukti.** Tag `v1.41.0`, 366 test (2 kasus rotasi baru), CI Analyze & Test
hijau, Release APK + AAB terbit.

## v1.40.0 — 23 Okt 2026 — catat satu kolom

**Masalah.** Form Catat punya dua isian (Nominal, Catatan). Cara tercepat user
mencatat adalah menulis "makan 25 ribu" di Catatan, lalu simpan ditolak dengan
"isi nominal dulu" — angkanya sudah ada di layar, tapi aplikasi tidak mau
membacanya. Ini backlog lama di `[[06-Roadmap]]` ("input cepat").

**Yang dikerjakan.** `parseQuickInput` (`lib/data/quick_parse.dart`) murni
string → angka dengan urutan prioritas: ribuan bertitik → angka + satuan
(`ribu|rb|k|juta|jt`) → angka polos ≥4 digit. Sisa teks jadi catatan.
Form menampilkan helper live dan memakai hasil parse **hanya** kalau kolom
nominal kosong.

**Keputusan yang diambil sendiri.** Angka <1000 tanpa satuan dan nilai
>Rp1 triliun menghasilkan `null`, bukan tebakan: "beli 3 telur" tidak boleh
jadi Rp3, dan salah nominal di aplikasi keuangan lebih mahal daripada satu
ketikan tambahan.

**Bukti.** Tag `v1.40.0`, 15 test `quick_parse_test.dart` (365 total), CI Analyze
& Test hijau, Release APK + AAB terbit.

## v1.39.0 — 23 Okt 2026 — backup tanpa tombol

**Masalah.** Satu-satunya salinan data adalah tombol "Backup database" di
Pengaturan → Kelola yang butuh dua keputusan (buka layar, pilih folder).
Realitanya jarang ditekan; HP hilang/rusak sebelum pernah ditekan = seluruh
catatan hilang. Sync Firestore bukan pengganti karena hanya dompet `isShared`
yang dikirim.

**Yang dikerjakan.** `AutoBackupController` (kelas biasa, tanpa widget) +
`AutoBackupBinder` pada `start`/`resume`: maksimal sekali per 20 jam, diam bila
switch mati, satu percobaan pada satu waktu, tidak pernah melempar. Salinan ke
`backups/mywallet-auto-YYYYMMDD-HHMM.sqlite` setelah `wal_checkpoint(TRUNCATE)`,
rotasi 5 terbaru. UI Kelola: status "Backup terakhir", tombol "Sekarang",
daftar salinan untuk dipulihkan.

**Keputusan yang diambil sendiri.** Default **menyala** (fitur ini justru untuk
user yang tidak pernah menekan tombol) dan pengingatnya berupa status di layar,
bukan notifikasi — menambah kanal notifikasi butuh izin baru dan berisiko
mengganggu, jadi dicatat sebagai backlog.

**Celah yang masih terbuka.** Salinan ini tinggal di HP yang sama. Kalau app
di-uninstall atau HP mati total, salinan ikut hilang — belum ada jalan keluar
otomatis ke Drive/WA. Lihat bagian bawah.

## Keputusan yang masih menggantung

- **Enkripsi DB lokal** — `mywallet.sqlite` masih SQLite biasa; PIN/biometrik
  hanya gerbang UI. Butuh `sqlcipher_flutter_libs` + migrasi
  plaintext→terenkripsi + uji di HP nyata. Sengaja TIDAK dikerjakan buta:
  kunci hilang = data hilang.
- **Crash reporting** — bertentangan dengan janji "100% offline, tanpa server"
  di `[[01-Visi-dan-Ruang-Lingkup]]`. Kalau tetap mau, harus opt-in dan
  dijelaskan di UI, bukan diam-diam.
- **Windows tanpa CI** — target `windows/` ada di repo tapi nol job CI
  (keputusan user: cukup CI GitHub untuk Android). Build Windows bisa rusak
  tanpa ada yang tahu.
- **Backup keluar HP** — lihat celah v1.39.0 di atas.
- **Pengingat backup** — masih status di layar, belum notifikasi.
