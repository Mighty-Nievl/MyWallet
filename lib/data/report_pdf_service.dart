import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';
import 'providers.dart';

/// Data siap-cetak satu laporan bulanan. Fungsi murni (tanpa ref)
/// agar bisa di-test dengan db in-memory.
class MonthReportData {
  const MonthReportData({
    required this.monthKey,
    required this.monthLabel,
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.transactions,
  });

  final String monthKey;
  final String monthLabel;
  final int income;
  final int expense;
  final List<CategoryTotal> byCategory;
  final List<TxWithCategory> transactions;

  int get net => income - expense;
}

/// Ambil semua data laporan satu bulan dari [db].
Future<MonthReportData> fetchMonthReport(
  AppDatabase db, {
  required String month,
  required DateTime from,
  required DateTime to,
}) async {
  final (income, expense) = await db.getTotals(from, to);
  final byCat = await db.totalsByCategory(from, to, true);
  // Urutan terbaru dulu (sama kayak layar Riwayat).
  final txs = await db.watchHistory(from: from, to: to, limit: 100000).first;
  return MonthReportData(
    monthKey: month,
    monthLabel: _monthLabelId(month),
    income: income,
    expense: expense,
    byCategory: byCat,
    transactions: txs,
  );
}

String _monthLabelId(String key) {
  const full = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]) ?? 0;
  if (m < 1 || m > 12) return key;
  return '${full[m - 1]} ${parts[0]}';
}

/// Bangun bytes PDF laporan dari [data].
///
/// 100% lokal (package `pdf`), tanpa server/API-key — selaras
/// janji offline-first MyWallet. Hirarki: judul → ringkasan →
/// rincian kategori (%) → daftar transaksi.
Future<Uint8List> buildMonthReportPdf(MonthReportData data) async {
  final doc = pw.Document(
    title: 'Laporan MyWallet ${data.monthLabel}',
    author: 'MyWallet',
  );

  final header = pw.TextStyle(
    fontSize: 20,
    fontWeight: pw.FontWeight.bold,
  );
  final sub = pw.TextStyle(fontSize: 11, color: PdfColors.grey700);
  final label = pw.TextStyle(fontSize: 10, color: PdfColors.grey600);
  final amount = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  final cell = pw.TextStyle(fontSize: 9);
  final cellBold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  pw.Widget summaryRow(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: label),
        pw.SizedBox(height: 2),
        pw.Text(value, style: amount),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) {
        final body = <pw.Widget>[
          pw.Text('Laporan ${data.monthLabel}', style: header),
          pw.SizedBox(height: 2),
          pw.Text(
            'MyWallet · dibuat ${DateTime.now().day} '
            '${_monthLabelId(_ym(DateTime.now()))} · ${data.transactions.length} transaksi',
            style: sub,
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              summaryRow('Pemasukan', _rp(data.income)),
              summaryRow('Pengeluaran', _rp(data.expense)),
              summaryRow(
                data.net < 0 ? 'Selisih (minus)' : 'Selisih',
                '${data.net < 0 ? '-' : '+'}${_rp(data.net.abs())}',
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Rincian pengeluaran per kategori',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
        ];

        if (data.byCategory.isEmpty) {
          body.add(pw.Text('Belum ada pengeluaran bulan ini.', style: cell));
        } else {
          final total =
              data.byCategory.fold<int>(0, (s, e) => s + e.total);
          body.add(
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Kategori', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('%', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Nominal', style: cellBold)),
                  ],
                ),
                for (final c in data.byCategory)
                  pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(c.name, style: cell)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            total == 0
                                ? '0%'
                                : '${(100 * c.total / total).round()}%',
                            style: cell)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_rp(c.total), style: cell)),
                  ]),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Total keluar', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('100%', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_rp(total), style: cellBold)),
                  ],
                ),
              ],
            ),
          );
        }

        body.add(pw.SizedBox(height: 16));
        body.add(pw.Text('Daftar transaksi',
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold)));
        body.add(pw.SizedBox(height: 6));

        if (data.transactions.isEmpty) {
          body.add(pw.Text('Belum ada transaksi bulan ini.', style: cell));
        } else {
          body.add(
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Tanggal', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Tipe', style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Kategori / catatan',
                            style: cellBold)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Nominal', style: cellBold)),
                  ],
                ),
                for (final t in data.transactions)
                  pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_date(t.date), style: cell)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            t.isExpense ? 'Keluar' : 'Masuk',
                            style: cell)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        [
                          t.catName ?? 'Tanpa kategori',
                          if (t.note.trim().isNotEmpty)
                            '— ${t.note.trim()}',
                        ].join(' '),
                        style: cell,
                      ),
                    ),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            '${t.isExpense ? '-' : '+'}${_rp(t.amount)}',
                            style: cell)),
                  ]),
              ],
            ),
          );
        }
        return body;
      },
    ),
  );

  return doc.save();
}

String _rp(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}Rp${buf.toString()}';
}

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _ym(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Service export PDF laporan bulanan.
///
/// 2 jalur keluar (sama kayak export CSV + backup):
/// - `exportMonthPdf`: simpan via share sheet ([share_plus])
/// - `saveMonthPdfToFile`: simpan via file picker.
/// Keduanya 100% lokal.
class ReportPdfService {
  /// Bangun + bagikan PDF bulan [monthKey] ("yyyy-MM").
  /// Return jumlah transaksi, 0 bila bulan kosong (tetap dibuatkan PDF).
  static Future<int> exportMonthPdf(
    WidgetRef ref, {
    required String monthKey,
  }) async {
    final db = ref.read(dbProvider);
    final (from, to) = monthRangeOf(monthKey);
    final data =
        await fetchMonthReport(db, month: monthKey, from: from, to: to);
    final bytes = await buildMonthReportPdf(data);

    final dir = await getTemporaryDirectory();
    final file = File(p.join(
        dir.path, 'mywallet-laporan-$monthKey.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Laporan MyWallet ${data.monthLabel}',
      ),
    );
    return data.transactions.length;
  }

  /// Simpan PDF bulan [monthKey] ke file pilihan user.
  /// Return Uri hasil, null bila batal.
  static Future<Uri?> saveMonthPdfToFile(
    WidgetRef ref, {
    required String monthKey,
  }) async {
    final db = ref.read(dbProvider);
    final (from, to) = monthRangeOf(monthKey);
    final data =
        await fetchMonthReport(db, month: monthKey, from: from, to: to);
    final bytes = await buildMonthReportPdf(data);
    return FilePicker.saveFile(
      dialogTitle: 'Simpan laporan ${data.monthLabel}',
      fileName: 'mywallet-laporan-$monthKey.pdf',
      bytes: bytes,
    );
  }
}
