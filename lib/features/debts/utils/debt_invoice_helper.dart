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
      List<DebtPayment> payments, StoreSettings settings, {Transaction? transaction}) async {
    
    // Optimization: If "Fast Raw" design is used with native transport, send straight data
    final transport = _mapTransport(settings.printerTransport);
    final isNativeTransport = transport == PrinterTransport.escposBluetooth ||
                              transport == PrinterTransport.escposUsb ||
                              transport == PrinterTransport.escposTcpIp;

    if (settings.invoiceDesign == 'fast' && isNativeTransport) {
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
        id: 'debt-receipt-fast',
        name: 'Fast Raw Debt Receipt',
        transport: transport,
        paperWidthMm: settings.receiptWidth,
        marginMm: settings.receiptMargin,
      );

      final result = await PrintOrchestrator().printReceipt(receipt, profile);
      if (result.success && result.bytes != null) {
        final printer = settings.invoicePrinterUrl != null 
            ? Printer(url: settings.invoicePrinterUrl!) 
            : const Printer(url: 'default');

        debugPrint('NATIVE-FAST-DEBT-PRINT: Sending ${result.bytes!.length} bytes to ${printer.url}');

        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) async => Uint8List.fromList(result.bytes!),
          format: PdfPageFormat.undefined,
        );
        return;
      }
    }

    // Direct PDF Optimization for Debt Invoices
    if (settings.useFastPrint) {
      final pdfBytes = await generateDebtPdf(
          customer: customer, debt: debt, payments: payments, settings: settings, transaction: transaction);
      
      final printer = settings.invoicePrinterUrl != null 
          ? Printer(url: settings.invoicePrinterUrl!) 
          : const Printer(url: 'default');

      debugPrint('DIRECT-PDF-DEBT-PRINT: Sending ${pdfBytes.length} bytes to ${printer.url} (Design: ${settings.invoiceDesign})');

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdfBytes,
      );
      return;
    }

    final pdfBytes = await generateDebtPdf(
        customer: customer, debt: debt, payments: payments, settings: settings, transaction: transaction);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Piutang-${customer.name}-${debt.invoiceNumber}',
    );
  }

  static Future<void> downloadDebtInvoice(Customer customer, Debt debt,
      List<DebtPayment> payments, StoreSettings settings, {Transaction? transaction}) async {
    final pdfBytes = await generateDebtPdf(
        customer: customer, debt: debt, payments: payments, settings: settings, transaction: transaction);
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
      case 'usb':       return PrinterTransport.escposUsb;
      case 'bluetooth': return PrinterTransport.escposBluetooth;
      case 'tcp':       return PrinterTransport.escposTcpIp;
      default:          return PrinterTransport.officePdf;
    }
  }
}
