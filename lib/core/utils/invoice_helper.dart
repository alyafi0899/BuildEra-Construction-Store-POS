import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../shared/models/transaction.dart';
import '../../../features/settings/models/store_settings.dart';
import 'formatters.dart';

class InvoiceHelper {
  static String? get _downloadsPath {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return '$userProfile\\Downloads';
      }
    }
    return null;
  }

  static Future<Uint8List> generatePdf(Transaction tx, StoreSettings settings) async {
    final pdf = pw.Document();
    
    // Auto-Fit Logic: Use 2mm margin as requested
    const double marginMm = 2.0;
    final double physicalWidth = settings.receiptWidth * PdfPageFormat.mm;
    final double marginPoints = marginMm * PdfPageFormat.mm;
    final double printableWidth = physicalWidth - (marginPoints * 2);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          physicalWidth,
          double.infinity,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.symmetric(
              vertical: 2 * PdfPageFormat.mm, 
              horizontal: marginPoints,
            ),
            child: pw.SizedBox(
              width: printableWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Column(children: [
                      pw.Text(settings.businessName.toUpperCase(), 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      if (settings.address.isNotEmpty)
                        pw.Text(settings.address, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                      if (settings.phone.isNotEmpty)
                        pw.Text('Telp: ${settings.phone}', style: const pw.TextStyle(fontSize: 8)),
                    ]),
                  ),
                  pw.Divider(thickness: 0.5),

                  // Info
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(Formatters.dateTime(tx.createdAt), style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Text('Kasir: ${tx.cashierName ?? 'Admin'}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('No: ${tx.invoiceNumber}', style: const pw.TextStyle(fontSize: 7)),
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
                              pw.Text(i.productName, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                              pw.Text('${Formatters.decimal(i.quantity)} ${i.unitName} x ${Formatters.currency(i.soldPrice)}', 
                                style: const pw.TextStyle(fontSize: 6)),
                              if (i.discountValue > 0)
                                pw.Text('Pot: ${Formatters.currency(i.discountValue)}${i.discountType.name == 'percentage' ? '%' : ''}', 
                                  style: const pw.TextStyle(fontSize: 6)),
                            ]
                          ),
                          pw.Text('', style: const pw.TextStyle(fontSize: 7)),
                          pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(Formatters.currency(i.subtotal), style: const pw.TextStyle(fontSize: 7)),
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
                  if (tx.shippingFee > 0)
                    _buildTotalRow('Ongkos Kirim', Formatters.currency(tx.shippingFee)),
                  
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

                  if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Catatan: ${tx.notes}', 
                      style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                      maxLines: 2),
                  ],

                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text('Terima Kasih atas Kunjungan Anda', 
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                  ),
                  
                  if ((tx.paymentMethod == 'Transfer Bank' || tx.paymentMethod == 'Piutang') && 
                      settings.bankAccounts.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                    pw.Text('PEMBAYARAN TRANSFER:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ...settings.bankAccounts.map((acc) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1),
                      child: pw.Text('${acc.bankName}: ${acc.accountNumber} a/n ${acc.accountHolder}', 
                        style: const pw.TextStyle(fontSize: 7)),
                    )),
                  ],

                  pw.SizedBox(height: 8),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Printed: ${Formatters.dateTime(DateTime.now())}', 
                      style: const pw.TextStyle(fontSize: 5)),
                  ),
                ],
              ),
            ),
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
    final filename = 'Invoice-${tx.invoiceNumber}.pdf';
    
    final dlPath = _downloadsPath;
    if (dlPath != null) {
      final file = File('$dlPath\\$filename');
      await file.writeAsBytes(pdfBytes);
      await OpenFilex.open(file.path);
    } else {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    }
  }
}
