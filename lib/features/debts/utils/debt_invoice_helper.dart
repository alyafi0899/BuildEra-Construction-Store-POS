import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/utils/formatters.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../../settings/models/store_settings.dart';

class DebtInvoiceHelper {
  static String? get _downloadsPath {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return '$userProfile\\Downloads';
      }
    }
    return null;
  }

  static Future<Uint8List> generateDebtPdf({
    required Customer customer,
    required Debt debt,
    required List<DebtPayment> payments,
    required StoreSettings settings,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          settings.receiptWidth * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(children: [
                    pw.Text(settings.businessName.toUpperCase(), 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.Text('NOTA PIUTANG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    if (settings.address.isNotEmpty)
                      pw.Text(settings.address, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                  ]),
                ),
                pw.Divider(thickness: 0.5),

                // Customer & Debt Info
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(Formatters.dateTime(debt.createdAt), style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Text('Pelanggan: ${customer.name}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (customer.phone.isNotEmpty)
                  pw.Text('Telp: ${customer.phone}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text('No. Invoice Asal: ${debt.invoiceNumber}', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Jatuh Tempo: ${Formatters.date(debt.dueDate)}', style: const pw.TextStyle(fontSize: 8)),
                if (debt.updatedAt.isAfter(debt.createdAt.add(Duration(minutes: 1))))
                  pw.Text('Update Terakhir: ${Formatters.dateTime(debt.updatedAt)}', style: pw.TextStyle(fontSize: 6)),
                
                pw.Divider(thickness: 0.5),

                // Debt Summary
                _buildRow('Total Piutang Awal', Formatters.currency(debt.totalAmount)),
                _buildRow('Total Sudah Bayar', Formatters.currency(debt.paidAmount)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SISA PIUTANG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text(Formatters.currency(debt.remainingBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                
                pw.Divider(thickness: 0.5),

                // Payment History
                pw.Text('RIWAYAT CICILAN / PEMBAYARAN:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                if (payments.isEmpty)
                  pw.Text('Belum ada riwayat pembayaran', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))
                else
                  ...payments.map((p) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(Formatters.dateTime(p.createdAt), style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(Formatters.currency(p.amount), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        if (p.notes != null)
                          pw.Text('Ket: ${p.notes}', style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  )),

                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                
                if (settings.bankAccounts.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('PEMBAYARAN TRANSFER:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ...settings.bankAccounts.map((acc) => pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1),
                    child: pw.Text('${acc.bankName}: ${acc.accountNumber} a/n ${acc.accountHolder}', 
                      style: const pw.TextStyle(fontSize: 7)),
                  )),
                  pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                ],

                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('Dokumen ini adalah bukti sah piutang', 
                    style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Printed: ${Formatters.dateTime(DateTime.now())}', 
                    style: const pw.TextStyle(fontSize: 5)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, color: color)),
        ],
      ),
    );
  }

  static Future<void> printDebtInvoice(Customer customer, Debt debt, List<DebtPayment> payments, StoreSettings settings) async {
    final pdfBytes = await generateDebtPdf(customer: customer, debt: debt, payments: payments, settings: settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Piutang-${customer.name}-${debt.invoiceNumber}',
    );
  }

  static Future<void> downloadDebtInvoice(Customer customer, Debt debt, List<DebtPayment> payments, StoreSettings settings) async {
    final pdfBytes = await generateDebtPdf(customer: customer, debt: debt, payments: payments, settings: settings);
    final filename = 'Piutang_${customer.name.replaceAll(' ', '_')}_${debt.invoiceNumber}.pdf';
    
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
