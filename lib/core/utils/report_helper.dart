import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../shared/models/transaction.dart';
import '../../features/settings/models/store_settings.dart';
import '../utils/formatters.dart';
import '../../features/payment/providers/transaction_provider.dart';

class ReportHelper {
  static String? get _downloadsPath {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return '$userProfile\\Downloads';
      }
    }
    return null;
  }

  static Future<void> generateAndDownloadReport({
    required List<Transaction> transactions,
    required String periodName,
    required StoreSettings settings,
    bool isShare = false,
  }) async {
    final pdf = pw.Document();
    final summary = buildSummary(transactions);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(settings.businessName.toUpperCase(), 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      pw.SizedBox(height: 2),
                      pw.Text(settings.address, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                      pw.Text('Telp: ${settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('LAPORAN PENJUALAN', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
                    pw.Text(periodName.toUpperCase(), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('Dicetak: ${Formatters.dateTime(DateTime.now())}', 
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 20),

            // KPI Grid
            pw.Row(
              children: [
                _buildKpiBox('Total Pendapatan', Formatters.currency(summary.totalRevenue), PdfColors.blue700),
                pw.SizedBox(width: 12),
                _buildKpiBox('Laba Bersih', Formatters.currency(summary.totalNetProfit), PdfColors.green700),
                pw.SizedBox(width: 12),
                _buildKpiBox('Total Transaksi', summary.totalTransactions.toString(), PdfColors.orange700),
              ],
            ),
            pw.SizedBox(height: 30),

            // Daily Details Table
            pw.Text('RINCIAN PER HARI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _th('Tanggal'),
                    _th('Txs', align: pw.TextAlign.center),
                    _th('Pendapatan', align: pw.TextAlign.right),
                    _th('Laba Bersih', align: pw.TextAlign.right),
                  ],
                ),
                ...summary.dailyDetails.map((d) => pw.TableRow(
                  children: [
                    _td(d.date),
                    _td(d.transactionCount.toString(), align: pw.TextAlign.center),
                    _td(Formatters.currency(d.revenue), align: pw.TextAlign.right),
                    _td(Formatters.currency(d.netProfit), align: pw.TextAlign.right),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 30),

            // Top Products
            pw.Text('10 PRODUK TERLARIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _th('Nama Produk'),
                    _th('Qty', align: pw.TextAlign.center),
                    _th('Pendapatan', align: pw.TextAlign.right),
                  ],
                ),
                ...summary.topProducts.map((p) => pw.TableRow(
                  children: [
                    _td(p.name),
                    _td(Formatters.decimal(p.qty), align: pw.TextAlign.center),
                    _td(Formatters.currency(p.revenue), align: pw.TextAlign.right),
                  ],
                )),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final cleanPeriod = periodName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final filename = 'Laporan_Penjualan_$cleanPeriod.pdf';

    if (isShare) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Penjualan $periodName');
    } else {
      final dlPath = _downloadsPath;
      if (dlPath != null) {
        final file = File('$dlPath\\$filename');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      } else {
        // Fallback for non-windows or if path failed
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    }
  }

  static pw.Widget _buildKpiBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: align),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: align),
    );
  }
}
