import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import 'setting_row.dart';

/// Kerangka halaman pengaturan — dulu disalin 4× (Tampilan, Privasi,
/// Kelola, Tentang): Scaffold → SafeArea → Column → BackHeader →
/// ListView(padding bawah 96).
///
/// Satu tempat = satu perilaku. Kalau padding bawah atau header berubah,
/// keempat halaman ikut tanpa ada yang ketinggalan.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.search,
  });

  final String title;
  final List<Widget> children;

  /// Biasanya [SettingsSearchField]; halaman tanpa pencarian (Tentang)
  /// membiarkannya null.
  final Widget? search;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: title),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s8,
                  AppSpacing.page,
                  // v1.45: 96 → 32. Halaman pengaturan tidak punya FAB
                  // (shell FAB hanya di Beranda), jadi 96 = ruang mati.
                  AppSpacing.sectionGapLarge,
                ),
                children: [
                  if (search != null) ...[
                    search!,
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom cari halaman pengaturan — controller + tombol bersih + normalisasi
/// query (trim + lowercase) di satu tempat, bukan diulang tiap halaman.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.query,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;

  /// Query aktif (sudah dinormalisasi) — menentukan tombol clear muncul.
  final String query;

  /// Menerima query yang SUDAH di-trim + lowercase.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      // v1.45 (a11y): tombol ikon wajib punya nama — dulu TalkBack cuma
      // bilang "tombol". autocorrect mati: ini kotak cari, bukan penulisan.
      autocorrect: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Bersihkan pencarian',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
      onChanged: (v) => onChanged(v.trim().toLowerCase()),
    );
  }
}
