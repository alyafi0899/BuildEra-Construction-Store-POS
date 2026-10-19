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
import '../../printing/services/windows_raw_spooler.dart';
import '../../printing/services/bluetooth_printer_service.dart';

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
      transport: _mapTransport(settings.printerTransport),
      paperWidthMm: settings.receiptWidth,
      marginMm: settings.receiptMargin,
    );

    final result = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    return Uint8List.fromList(result.bytes ?? []);
  }

  static Future<void> printInvoice(
      Transaction tx, StoreSettings settings) async {
    final transport = _mapTransport(settings.printerTransport);

    if (Platform.isAndroid &&
        transport == PrinterTransport.escposBluetooth) {
      final address = settings.invoicePrinterUrl;
      if (address == null || address.isEmpty) {
        throw StateError(
          'Pilih dan hubungkan printer Bluetooth di Pengaturan Printer '
          'sebelum mencetak.',
        );
      }

      final receipt = ReceiptDocument(
        title: settings.businessName.toUpperCase(),
        lines: [],
        metadata: {'transaction': tx, 'settings': settings},
      );
      final profile = PrinterProfile(
        id: 'receipt-bluetooth',
        name: 'Bluetooth Receipt',
        transport: transport,
        paperWidthMm: settings.receiptWidth,
        marginMm: settings.receiptMargin,
      );
      await BluetoothPrinterService().printReceipt(
        address: address,
        receipt: receipt,
        profile: profile,
      );
      return;
    }

    // --- CASE 1: DIRECT RAW (The New "Straight Data" System) ---
    // Use this for maximum speed and to avoid "Soft Font" vs "Image" issues on Windows.
    if (settings.printMethod == 'raw' &&
        Platform.isWindows &&
        settings.invoicePrinterUrl != null) {
      final receipt = ReceiptDocument(
        title: settings.businessName.toUpperCase(),
        lines: [],
        metadata: {'transaction': tx, 'settings': settings},
      );

      final profile = PrinterProfile(
        id: 'receipt-raw',
        name: 'Direct Raw Receipt',
        transport: transport,
        paperWidthMm: settings.receiptWidth,
        marginMm: settings.receiptMargin,
      );

      // We use EscPosDriver directly to get raw bytes
      final result = await PrintOrchestrator().printReceipt(receipt, profile);
      if (result.success && result.bytes != null) {
        await WindowsRawSpooler.printRaw(
            settings.invoicePrinterUrl!, result.bytes!);
        return;
      }
    }

    // --- CASE 2: NATIVE NETWORK (TCP) ---
    if (settings.invoiceDesign == 'fast' &&
        transport == PrinterTransport.escposTcpIp &&
        settings.invoicePrinterUrl != null) {
      final receipt = ReceiptDocument(
        title: settings.businessName.toUpperCase(),
        lines: [],
        metadata: {'transaction': tx, 'settings': settings},
      );

      final profile = PrinterProfile(
        id: 'receipt-tcp',
        name: 'TCP Raw Receipt',
        transport: transport,
        paperWidthMm: settings.receiptWidth,
        marginMm: settings.receiptMargin,
      );

      final result = await PrintOrchestrator().printReceipt(receipt, profile);
      if (result.success && result.bytes != null) {
        await _printRawTcp(settings.invoicePrinterUrl!, result.bytes!);
        return;
      }
    }

    // --- CASE 3: DIRECT PDF (The High Fidelity "Print as Image" System) ---
    if (settings.useFastPrint) {
      final pdfBytes = await generatePdf(tx, settings);
      final printer = settings.invoicePrinterUrl != null
          ? Printer(url: settings.invoicePrinterUrl!)
          : const Printer(url: 'default');

      debugPrint(
          'DIRECT-PDF-PRINT: Sending ${pdfBytes.length} bytes to ${printer.url} (Design: ${settings.invoiceDesign})');

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
      );
      return;
    }

    // --- CASE 4: INTERACTIVE PRINT ---
    final pdfBytes = await generatePdf(tx, settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice-${tx.invoiceNumber}',
    );
  }

  static Future<void> _printRawTcp(String url, List<int> bytes) async {
    try {
      // Parse IP and Port (default 9100)
      final parts = url.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

      debugPrint('NATIVE-TCP-PRINT: Connecting to $host:$port...');
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      debugPrint('NATIVE-TCP-PRINT: Success (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('NATIVE-TCP-PRINT: Error - $e');
    }
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

  static PrinterTransport _mapTransport(String t) {
    switch (t) {
      case 'usb':
        return PrinterTransport.escposUsb;
      case 'bluetooth':
        return PrinterTransport.escposBluetooth;
      case 'tcp':
        return PrinterTransport.escposTcpIp;
      default:
        return PrinterTransport.officePdf;
    }
  }
}
