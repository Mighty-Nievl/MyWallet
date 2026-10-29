import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';
import 'providers.dart';

/// Hasil satu export CSV: berapa baris data (di luar header) dan di mana
/// file sementaranya.
typedef CsvExportResult = ({int rows, String path});

/// Export transaksi ke CSV — logika yang dulu menempel di
/// `SettingsActions.exportCsv` (UI mixin, tanpa try/catch, tanpa tes).
///
/// Dipisah ke sini supaya:
/// 1. isi CSV bisa diuji tanpa widget (`buildTransactionsCsv` murni);
/// 2. kegagalan I/O/share bisa ditangkap pemanggil dan diterjemahkan jadi
///    pesan, bukan exception mentah ke framework;
/// 3. ambang 100.000 baris punya satu tempat yang jelas.
abstract final class ExportService {
  /// Batas atas ekspor. Di atas ini ekspor dipotong, bukan menggantung.
  static const maxRows = 100000;

  /// CSV dari daftar transaksi. Murni — tidak menyentuh DB/disk.
  ///
  /// Kolom & urutan sengaja dipertahankan sama seperti v1.16–v1.42 supaya
  /// file lama dan baru bisa dibuka dengan spreadsheet yang sama.
  static String buildTransactionsCsv(List<TxWithCategory> rows) {
    final csvRows = <List<dynamic>>[
      ['tanggal', 'tipe', 'kategori', 'nominal', 'catatan'],
      for (final t in rows)
        [
          t.date.toIso8601String(),
          t.isExpense ? 'keluar' : 'masuk',
          t.catName ?? '',
          t.amount,
          t.note,
        ],
    ];
    return Csv().encode(csvRows);
  }

  /// Baca transaksi (maks. [maxRows]), tulis CSV ke folder sementara, lalu
  /// bagikan lewat sheet sistem. Melempar bila DB/berkas/share gagal —
  /// pemanggil yang memutuskan pesannya.
  static Future<CsvExportResult> exportTransactionsCsv(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final rows = await db.watchHistory(limit: maxRows).first;
    final csv = buildTransactionsCsv(rows);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'mywallet-$stamp.csv'));
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Export MyWallet CSV'),
    );
    return (rows: rows.length, path: file.path);
  }
}
