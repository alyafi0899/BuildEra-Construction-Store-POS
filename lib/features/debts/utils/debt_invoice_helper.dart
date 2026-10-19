import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import '../../../printing/printing.dart';
import '../../../shared/models/transaction.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../../settings/models/store_settings.dart';
import '../../../printing/services/windows_raw_spooler.dart';
import '../../../printing/services/bluetooth_printer_service.dart';

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
    Transaction? transaction,
  }) async {
    final receipt = ReceiptDocument(
      title: 'NOTA PIUTANG',
      lines: [],
      metadata: {
        'customer': customer,
        'debt': debt,
        'payments': payments,
        'settings': settings,
        'transaction': transaction,
      },
    );

    final profile = PrinterProfile(
      id: 'debt-receipt',
      name: 'Debt Receipt',
      transport: _mapTransport(settings.printerTransport),
      paperWidthMm: settings.receiptWidth,
      marginMm: settings.receiptMargin,
    );

    final result = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    return Uint8List.fromList(result.bytes ?? []);
  }

  static Future<void> printDebtInvoice(Customer customer, Debt debt,
      List<DebtPayment> payments, StoreSettings settings,
      {Transaction? transaction}) async {
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
        title: 'NOTA PIUTANG',
        lines: [],
        metadata: {
          'customer': customer,
          'debt': debt,
          'payments': payments,
          'settings': settings,
          'transaction': transaction,
        },
      );
      final profile = PrinterProfile(
        id: 'debt-receipt-bluetooth',
        name: 'Bluetooth Debt Receipt',
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

    // --- CASE 1: DIRECT RAW ---
    if (settings.printMethod == 'raw' &&
        Platform.isWindows &&
        settings.invoicePrinterUrl != null) {
      final receipt = ReceiptDocument(
        title: 'NOTA PIUTANG',
        lines: [],
        metadata: {
          'customer': customer,
          'debt': debt,
          'payments': payments,
          'settings': settings,
          'transaction': transaction,
        },
      );

      final profile = PrinterProfile(
        id: 'debt-receipt-raw',
        name: 'Direct Raw Debt Receipt',
        transport: transport,
        paperWidthMm: settings.receiptWidth,
        marginMm: settings.receiptMargin,
      );

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
        title: 'NOTA PIUTANG',
        lines: [],
        metadata: {
          'customer': customer,
          'debt': debt,
          'payments': payments,
          'settings': settings,
          'transaction': transaction,
        },
      );

      final profile = PrinterProfile(
        id: 'debt-receipt-tcp',
        name: 'TCP Raw Debt Receipt',
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

    // Direct PDF Optimization for Debt Invoices
    if (settings.useFastPrint) {
      final pdfBytes = await generateDebtPdf(
          customer: customer,
          debt: debt,
          payments: payments,
          settings: settings,
          transaction: transaction);

      final printer = settings.invoicePrinterUrl != null
          ? Printer(url: settings.invoicePrinterUrl!)
          : const Printer(url: 'default');

      debugPrint(
          'DIRECT-PDF-DEBT-PRINT: Sending ${pdfBytes.length} bytes to ${printer.url} (Design: ${settings.invoiceDesign})');

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
      );
      return;
    }

    final pdfBytes = await generateDebtPdf(
        customer: customer,
        debt: debt,
        payments: payments,
        settings: settings,
        transaction: transaction);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Piutang-${customer.name}-${debt.invoiceNumber}',
    );
  }

  static Future<void> _printRawTcp(String url, List<int> bytes) async {
    try {
      final parts = url.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

      debugPrint('NATIVE-TCP-DEBT-PRINT: Connecting to $host:$port...');
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      debugPrint('NATIVE-TCP-DEBT-PRINT: Success (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('NATIVE-TCP-DEBT-PRINT: Error - $e');
    }
  }

  static Future<void> downloadDebtInvoice(Customer customer, Debt debt,
      List<DebtPayment> payments, StoreSettings settings,
      {Transaction? transaction}) async {
    final pdfBytes = await generateDebtPdf(
        customer: customer,
        debt: debt,
        payments: payments,
        settings: settings,
        transaction: transaction);
    final filename =
        'Piutang_${customer.name.replaceAll(' ', '_')}_${debt.invoiceNumber}.pdf';

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
