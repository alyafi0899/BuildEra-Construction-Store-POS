import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../../shared/models/transaction.dart';
import '../../../features/settings/models/store_settings.dart';
import '../../printing/printing.dart';

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

  static Future<Uint8List> generatePdf(
      Transaction tx, StoreSettings settings) async {
    final receipt = ReceiptDocument(
      title: settings.businessName.toUpperCase(),
      lines: [],
      metadata: {'transaction': tx, 'settings': settings},
    );

    final profile = PrinterProfile(
      id: 'receipt-default',
      name: 'Receipt Default',
      transport: PrinterTransport.officePdf,
      paperWidthMm: settings.receiptWidth,
      marginMm: settings.receiptMargin,
    );

    final result = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    return Uint8List.fromList(result.bytes ?? []);
  }

  static Future<void> printInvoice(
      Transaction tx, StoreSettings settings) async {
    // Optimization: If useFastPrint is ON, we use Direct PDF (no dialog)
    // We send a valid PDF because Windows Spooler doesn't accept raw bytes via standard API
    if (settings.useFastPrint) {
      final pdfBytes = await generatePdf(tx, settings);
      final printer = settings.invoicePrinterUrl != null 
          ? Printer(url: settings.invoicePrinterUrl!) 
          : const Printer(url: 'default');

      debugPrint('DIRECT-PDF-PRINT: Sending ${pdfBytes.length} bytes to ${printer.url}');

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
      );
      return;
    }

    // Normal mode: Show Dialog
    final pdfBytes = await generatePdf(tx, settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice-${tx.invoiceNumber}',
    );
  }

  static Future<void> shareInvoice(
      Transaction tx, StoreSettings settings) async {
    final pdfBytes = await generatePdf(tx, settings);

    if (kIsWeb) {
      await Printing.sharePdf(
          bytes: pdfBytes, filename: 'Invoice-${tx.invoiceNumber}.pdf');
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Invoice-${tx.invoiceNumber}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Invoice ${tx.invoiceNumber}');
    }
  }

  static Future<void> saveInvoice(
      Transaction tx, StoreSettings settings) async {
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
