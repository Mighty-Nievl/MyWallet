import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../changelog.dart';
import '../components/app_feedback.dart';
import '../components/setting_row.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// Halaman Changelog penuh — menggantikan bottom-sheet 85% v1.16.x.
///
/// Kritik brutal yang dijawab di sini (bukan klaim, lihat test):
/// 1. Isi = commit log developer → tiap entri kini dua lapis: [user]
///    (bahasa manusia, selalu tampil) + [tech] (detail teknis, collapsed).
/// 2. Tembok teks → tiap entri = judul versi + tanggal + 1-2 kalimat user
///    + peringatan breaking (bila ada) + detail teknis opsional.
/// 3. Badge "TERBARU" bohong (i==0) → penanda jujur: versi yang TERINSTALL
///    di HP ini (via PackageInfo), bukan entri teratas list.
/// 4. Modal untuk konten referensi panjang → halaman penuh: tidak ada konflik
///    scroll-vs-drag-sheet, bisa di-back, bisa di-deep-link.
/// 5. Tanpa tanggal → tiap entri bertanggal (sumber docs/07-Rilis).
/// 6. Entri purba bobot sama → 3 versi terakhir tampil penuh, sisanya
///    collapsed dalam satu grup "Versi lama".
class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  /// 3 versi terakhir tampil penuh; sisanya masuk grup collapsed.
  static const recentCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.s8,
                AppSpacing.page,
                0,
              ),
              child: BackHeader(title: 'Changelog'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  // PackageInfo gagal (mis. platform aneh) BUKAN alasan
                  // halaman stuck di skeleton: render list tanpa badge
                  // TERINSTALL. Ditemukan saat test widget (plugin tidak
                  // ada di test env → future error → skeleton selamanya).
                  final installed = snap.data == null
                      ? null
                      : 'v${snap.data!.version}';
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData &&
                      !snap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.page),
                      child: AppSkeleton(lines: 4),
                    );
                  }
                  final recent = appChangelog.take(recentCount).toList();
                  final older = appChangelog.skip(recentCount).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.s8,
                      AppSpacing.page,
                      96,
                    ),
                    children: [
                      for (final e in recent)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s8,
                          ),
                          child: _EntryCard(
                            entry: e,
                            isInstalled: installed == e.version,
                          ),
                        ),
                      if (older.isNotEmpty)
                        _OlderGroup(
                          entries: older,
                          installed: installed,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu kartu entri: badge versi + tanggal + penanda terinstall,
/// copy per entri, peringatan breaking, detail teknis collapsible.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.isInstalled});

  final ({String? breaking, String date, String tech, String user, String version}) entry;
  final bool isInstalled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isInstalled
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.12),
                scheme.surface,
              )
            : scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isInstalled
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: isInstalled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isInstalled
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.version,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isInstalled
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Expanded mendorong tombol salin ke tepi kanan; tanggal +
              // TERINSTALL pindah ke baris caption di bawah (insiden:
              // badge + tanggal + TERINSTALL + tombol 48px jebol 51px
              // di viewport 300px — empat lebar-tetap dalam satu Row).
              const Expanded(child: SizedBox.shrink()),
              // Salin per entri (48px, ikut token touchMin) — user bisa
              // paste ke laporan bug tanpa ketik manual.
              SizedBox(
                width: AppSpacing.touchMin,
                height: AppSpacing.touchMin,
                child: IconButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${entry.version} (${entry.date})\n${entry.user}',
                      ),
                    );
                    if (!context.mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${entry.version} disalin — tempel saat lapor bug.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Salin ${entry.version}',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          // Caption tanggal + penanda jujur: versi TERINSTALL di HP ini
          // (via PackageInfo) — bukan "paling atas di list" seperti badge
          // TERBARU v1.16.x. Satu baris rich-text: selalu muat + wrap aman.
          Text.rich(
            TextSpan(
              style: AppType.secondary(context),
              children: [
                TextSpan(text: entry.date),
                if (isInstalled)
                  TextSpan(
                    text: ' · TERINSTALL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(entry.user, style: Theme.of(context).textTheme.bodyMedium),
          if (entry.breaking != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      entry.breaking!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          Theme(
            // Hilangkan divider + padding bawaan ExpansionTile agar ikut
            // bahasa desain kartu (tanpa garis aneh di dalam kartu).
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              minTileHeight: AppSpacing.touchMin,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'Detail teknis',
                style: AppType.secondary(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    entry.tech,
                    style: AppType.secondary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grup collapsed untuk versi lama — bobot visual kecil, tidak menyaingi
/// 3 versi terakhir, tapi tetap bisa dibuka + disalin per entri.
class _OlderGroup extends StatelessWidget {
  const _OlderGroup({required this.entries, required this.installed});

  final List<({String? breaking, String date, String tech, String user, String version})> entries;
  final String? installed;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
        ),
        collapsedBackgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow,
        minTileHeight: AppSpacing.touchMin,
        leading: const Icon(Icons.history),
        title: Text(
          'Versi lama (${entries.length})',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: _EntryCard(
                entry: e,
                isInstalled: installed == e.version,
              ),
            ),
        ],
      ),
    );
  }
}
