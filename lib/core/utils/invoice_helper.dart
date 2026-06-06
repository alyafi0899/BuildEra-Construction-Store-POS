import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../shared/models/transaction.dart';
import '../../../features/settings/models/store_settings.dart';
import 'formatters.dart';

class InvoiceHelper {
  static Future<Uint8List> generatePdf(Transaction tx, StoreSettings settings) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(children: [
                  pw.Text(settings.businessName.toUpperCase(), 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  if (settings.address.isNotEmpty)
                    pw.Text(settings.address, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                  if (settings.phone.isNotEmpty)
                    pw.Text('Telp: ${settings.phone}', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
              pw.Divider(thickness: 0.5),

              // Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No: ${tx.invoiceNumber}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(Formatters.date(tx.createdAt), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Text('Kasir: ${tx.cashierName ?? 'Admin'}', style: const pw.TextStyle(fontSize: 8)),
              if (tx.customerName != null)
                pw.Text('Plg: ${tx.customerName}', style: const pw.TextStyle(fontSize: 8)),
              
              pw.Divider(thickness: 0.5),

              // Items Table
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  ...tx.items.map((i) => pw.TableRow(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(i.productName, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${Formatters.decimal(i.quantity)} ${i.unitName} x ${Formatters.currency(i.soldPrice)}', 
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          if (i.discountValue > 0)
                            pw.Text('Disc: ${Formatters.currency(i.discountValue)}${i.discountType.name == 'percentage' ? '%' : ''}', 
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.green)),
                        ]
                      ),
                      pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(Formatters.currency(i.subtotal), style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ]
                  )),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Totals
              _buildTotalRow('Subtotal', Formatters.currency(tx.subtotal)),
              if (tx.itemDiscountTotal > 0)
                _buildTotalRow('Pot. Item', '-${Formatters.currency(tx.itemDiscountTotal)}'),
              if (tx.transDiscountAmount > 0)
                _buildTotalRow('Disc Trans', '-${Formatters.currency(tx.transDiscountAmount)}'),
              if (tx.taxAmount > 0)
                _buildTotalRow('PPN (11%)', Formatters.currency(tx.taxAmount)),
              
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(Formatters.currency(tx.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              _buildTotalRow('Bayar (${tx.paymentMethod})', Formatters.currency(tx.amountPaid)),
              _buildTotalRow('Kembali', Formatters.currency(tx.changeAmount)),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Terima Kasih atas Kunjungan Anda', 
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
              if (settings.bankName.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text('Pembayaran via ${settings.bankName}: ${settings.bankAccount}', 
                    style: const pw.TextStyle(fontSize: 7)),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static Future<void> printInvoice(Transaction tx, StoreSettings settings) async {
    final pdfBytes = await generatePdf(tx, settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice-${tx.invoiceNumber}',
    );
  }

  static Future<void> shareInvoice(Transaction tx, StoreSettings settings) async {
    final pdfBytes = await generatePdf(tx, settings);
    
    if (kIsWeb) {
      // Web doesn't support share_plus for files easily, so we just download
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Invoice-${tx.invoiceNumber}.pdf');
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Invoice-${tx.invoiceNumber}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice ${tx.invoiceNumber}');
    }
  }

  static Future<void> saveInvoice(Transaction tx, StoreSettings settings) async {
    final pdfBytes = await generatePdf(tx, settings);
    // On web, this triggers download. On desktop/mobile, it shows printer dialog (most direct way to save as PDF)
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Invoice-${tx.invoiceNumber}.pdf');
  }
}
