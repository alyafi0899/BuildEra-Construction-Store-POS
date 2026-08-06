import 'dart:io';
import 'dart:typed_data';
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
      lines: [], // Lines no longer used, logic moved to metadata-driven PDF builder
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
      transport: PrinterTransport.officePdf,
      paperWidthMm: settings.receiptWidth,
      marginMm: settings.receiptMargin,
    );

    final result = await PrintOrchestrator().buildReceiptPdf(receipt, profile);
    return Uint8List.fromList(result.bytes ?? []);
  }

  static Future<void> printDebtInvoice(Customer customer, Debt debt,
      List<DebtPayment> payments, StoreSettings settings, {Transaction? transaction}) async {
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
}
