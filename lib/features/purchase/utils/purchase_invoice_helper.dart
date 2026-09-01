import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io' show Platform;
import '../../../core/utils/formatters.dart';
import '../../../shared/models/purchase.dart';
import '../../settings/models/store_settings.dart';
import '../../../printing/printing.dart';
import '../../../printing/services/windows_raw_spooler.dart';

class PurchaseInvoiceHelper {
  static Future<Uint8List> generatePurchasePdf({
    required Purchase purchase,
    required StoreSettings settings,
  }) async {
    final pdf = pw.Document();

    // Load logo if exists
    pw.ImageProvider? logo;
    if (settings.logoUrl != null && settings.logoUrl!.isNotEmpty) {
      try {
        logo = await networkImage(settings.logoUrl!);
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // ── Header ────────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(height: 60, child: pw.Image(logo))
                    else
                      pw.Text(settings.businessName.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(settings.address,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Telp: ${settings.phone}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SURAT PEMBELIAN',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    child: pw.Text('No. Nota: ${purchase.invoiceNumber}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Tanggal: ${Formatters.dateTime(purchase.createdAt)}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),

          pw.Divider(thickness: 2, color: PdfColors.grey300, height: 40),

          // ── Info Supplier & Staff ─────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SUPPLIER:',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(purchase.supplierName ?? 'Umum / Tanpa Supplier',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PENERIMA (STAFF):',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(purchase.staffName ?? 'Admin',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // ── Table Items ───────────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headerAlignment: pw.Alignment.center,
            headers: ['Nama Produk', 'Harga Beli', 'Qty', 'Satuan', 'Subtotal'],
            data: purchase.items.map((item) {
              return [
                item.productName,
                Formatters.currency(item.purchasePrice),
                Formatters.decimal(item.quantity),
                item.unitName,
                Formatters.currency(item.subtotal),
              ];
            }).toList(),
          ),

          // ── Summary ───────────────────────────────────────────────────────
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                child: pw.Column(
                  children: [
                    _summaryRow('Subtotal', Formatters.currency(purchase.subtotal)),
                    _summaryRow('Biaya Kirim', Formatters.currency(purchase.shippingFee)),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    _summaryRow('TOTAL AKHIR', Formatters.currency(purchase.total), isBold: true, fontSize: 14),
                    _summaryRow('Dibayar', Formatters.currency(purchase.amountPaid)),
                    if (purchase.total > purchase.amountPaid)
                      _summaryRow('Sisa Hutang', Formatters.currency(purchase.total - purchase.amountPaid), color: PdfColors.red900),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 50),

          // ── Signatures ────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Text('Hormat Kami,', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 60),
                  pw.Text('( ____________________ )', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Supplier', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Penerima,', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 60),
                  pw.Text('( ${purchase.staffName ?? "Admin"} )',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Staff Gudang', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text('Terima kasih atas kerjasama Anda.', 
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryRow(String label, String value,
      {bool isBold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  static Future<void> printInvoice(Purchase p, StoreSettings s) async {
    // --- CASE: THERMAL (RECEIPT) ---
    final receipt = ReceiptDocument(
      title: 'PEMBELIAN',
      lines: [],
      metadata: {'purchase': p, 'settings': s},
    );

    final profile = PrinterProfile(
      id: 'purchase-receipt',
      name: 'Purchase Receipt',
      transport: _mapTransport(s.printerTransport),
      paperWidthMm: s.receiptWidth,
      marginMm: s.receiptMargin,
    );

    if (s.printMethod == 'raw' && Platform.isWindows && s.invoicePrinterUrl != null) {
      final result = await PrintOrchestrator().printReceipt(receipt, profile);
      if (result.success && result.bytes != null) {
        await WindowsRawSpooler.printRaw(s.invoicePrinterUrl!, result.bytes!);
        return;
      }
    }

    final pdfBytes = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    await Printing.layoutPdf(
      onLayout: (_) => Uint8List.fromList(pdfBytes.bytes!),
      name: 'Struk-Beli-${p.invoiceNumber}',
    );
  }

  static Future<void> printInvoiceA4(Purchase p, StoreSettings s) async {
    final pdf = await generatePurchasePdf(purchase: p, settings: s);
    await Printing.layoutPdf(
      onLayout: (_) => pdf,
      name: 'A4-Pembelian-${p.invoiceNumber}',
    );
  }

  static Future<void> saveInvoice(Purchase p, StoreSettings s) async {
    final pdf = await generatePurchasePdf(purchase: p, settings: s);
    await Printing.sharePdf(
      bytes: pdf,
      filename: 'Nota-Beli-A4-${p.invoiceNumber}.pdf',
    );
  }

  static Future<void> saveInvoiceThermal(Purchase p, StoreSettings s) async {
    final receipt = ReceiptDocument(
      title: 'PEMBELIAN',
      lines: [],
      metadata: {'purchase': p, 'settings': s},
    );

    final profile = PrinterProfile(
      id: 'purchase-receipt',
      name: 'Purchase Receipt',
      transport: _mapTransport(s.printerTransport),
      paperWidthMm: s.receiptWidth,
      marginMm: s.receiptMargin,
    );

    final result = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    await Printing.sharePdf(
      bytes: Uint8List.fromList(result.bytes!),
      filename: 'Struk-Beli-Thermal-${p.invoiceNumber}.pdf',
    );
  }

  static Future<void> shareInvoice(Purchase p, StoreSettings s) async {
    final pdf = await generatePurchasePdf(purchase: p, settings: s);
    await Printing.sharePdf(
      bytes: pdf,
      filename: 'Nota-Beli-${p.invoiceNumber}.pdf',
    );
  }

  static PrinterTransport _mapTransport(String t) {
    switch (t) {
      case 'usb':       return PrinterTransport.escposUsb;
      case 'bluetooth': return PrinterTransport.escposBluetooth;
      case 'tcp':       return PrinterTransport.escposTcpIp;
      default:          return PrinterTransport.officePdf;
    }
  }
}
