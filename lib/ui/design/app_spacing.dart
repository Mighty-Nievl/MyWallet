import 'package:flutter/widgets.dart';

/// Skala spacing konsisten. Pakai salah satu nilai ini —
/// hindari angka arbitrer (13, 17, 23, ...) tanpa alasan kuat.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// Padding horizontal halaman.
  static const double page = s16;

  /// Jarak antar section besar (saldo -> harian -> kategori -> riwayat).
  static const double sectionGap = s24;

  /// Jarak antar section LEGA ala B2C (Beranda v1.24+: hero→monthnav→seksi).
  /// B2C v1.24.2: token resmi, bukan literal 32 tersebar.
  static const double sectionGapLarge = s32;

  /// Jarak judul section ke kontennya.
  static const double groupGap = s12;

  /// Micro-gap optik judul→subtitle dalam satu baris (2px, bukan skala).
  /// Disatukan biar satu sumber — render tidak berubah 1px pun.
  static const double micro = 2;

  /// Padding dalam kartu.
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);

  /// Padding dalam kartu BESAR (hero saldo): lega 24.
  /// B2C v1.24.2: hero pakai ini, bukan literal all(24).
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(s24);

  /// Ruang kosong selebar FAB + margin notch (56 + 2×8).
  /// Tanpa ini tab Budget/Laporan ketindih cekungan (legacy BottomAppBar).
  /// M3 NavigationBar tidak butuh ini — dipertahankan untuk kompatibilitas.
  static const double navFabGap = 72;

  /// Tinggi bar navigasi custom legacy (M3 NavigationBar atur sendiri).
  static const double navBarHeight = 56;

  /// Ruang napas bawah agar konten terakhir tidak tertutup kapsul FAB.
  /// RUMUS (v1.32.6, audit prinsipil): clearance = dockSlot (68) +
  /// safeBottom aktual + dockBreath (44). dockSlot = isi 56 + celah
  /// bawah (dulu margin 12; sejak v1.33.0 kFloatingActionButtonMargin
  /// 16 — nilainya SENGAJA tidak diubah supaya clearance 112 tetap
  /// konsisten, breath efektif jadi 40). safeBottom emulator = 0
  /// → 112 pas; HP gesture-nav ≈ 16-24 → butuh 128-136. Karena itu
  /// Beranda (satu-satunya body shell) memakai
  /// `bottomPad + MediaQuery.paddingOf(context).bottom`; 9 layar lain
  /// (Scaffold sendiri, kapsul tak tampil saat push) tetap token statis.
  /// v1.33.0: kapsul pindah ke slot FAB → body penuh (konten boleh lewat
  /// di belakang kapsul), jadi ekor ini satu-satunya penjaga kartu
  /// terakhir saat scroll mentok.
  static const double bottomPad = 112;

  /// Slot vertikal kapsul FAB: isi kapsul 56 + celah bawah 12 (terukur,
  /// bukan tebakan; border 2 di dalam isi). v1.33.0: kapsul pindah ke
  /// slot FAB, Scaffold menambah kFloatingActionButtonMargin 16 sendiri
  /// — nilai 68 SENGAJA tidak diubah (breath efektif 40, clearance 112
  /// sudah lolos probe & regression test).
  static const double dockSlot = 68;

  /// Napas lega di atas dock agar konten terakhir terlihat penuh +
  /// terjangkau jempol (B2C, bukan angka arbitrer).
  static const double dockBreath = 44;

  /// Target sentuh minimum Material (48×48).
  static const double touchMin = 48;

  /// Tinggi tombol aksi utama (hero Beranda): lega 52.
  /// B2C v1.24.3: token resmi, bukan literal di hero.
  static const double ctaHeight = 52;
}
