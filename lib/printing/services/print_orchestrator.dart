import '../models/label_template.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';
import '../../features/settings/models/store_settings.dart';
import 'receipt_layout_service.dart';
import 'label_layout_service.dart';
import '../drivers/pdf/pdf_driver.dart';
import '../drivers/escpos/escpos_driver.dart';
import '../drivers/tspl/tspl_driver.dart';
import '../drivers/zpl/zpl_driver.dart';

class PrintOrchestrator {
  final ReceiptLayoutService receiptLayoutService;
  final LabelLayoutService labelLayoutService;

  PrintOrchestrator(
      {ReceiptLayoutService? receiptLayoutService,
      LabelLayoutService? labelLayoutService})
      : receiptLayoutService = receiptLayoutService ?? ReceiptLayoutService(),
        labelLayoutService = labelLayoutService ?? LabelLayoutService();

  Future<PrintResult> buildReceiptPdf(
      ReceiptDocument receipt, PrinterProfile profile) async {
    final bytes = await receiptLayoutService.buildPdf(receipt, profile);
    return PdfDriver().printReceipt(receipt, profile, bytes: bytes);
  }

  Future<PrintResult> printReceipt(
      ReceiptDocument receipt, PrinterProfile profile) async {
    final settings = receipt.metadata['settings'] as StoreSettings?;
    
    // If "Fast Raw" design is selected and we are using an ESC/POS transport, 
    // bypass PDF rendering and send native data.
    if (settings?.invoiceDesign == 'fast' && 
        (profile.transport == PrinterTransport.escposBluetooth ||
         profile.transport == PrinterTransport.escposUsb ||
         profile.transport == PrinterTransport.escposTcpIp)) {
      return EscPosDriver().printReceipt(receipt, profile);
    }

    switch (profile.transport) {
      case PrinterTransport.escposBluetooth:
      case PrinterTransport.escposUsb:
      case PrinterTransport.escposTcpIp:
        // Default to PDF rendering for non-fast designs on ESC/POS
        // This ensures Classic/Modern styles look consistent
        return buildReceiptPdf(receipt, profile);
      case PrinterTransport.officePdf:
        return buildReceiptPdf(receipt, profile);
      case PrinterTransport.tspl:
      case PrinterTransport.zpl:
        return const PrintResult(
            success: false,
            message: 'Thermal transport selected for a receipt.');
    }
  }

  Future<PrintResult> printLabel(LabelDocument label, PrinterProfile profile,
      {LabelTemplateSettings? settings}) async {
    switch (profile.transport) {
      case PrinterTransport.tspl:
        return TsplDriver().printLabel(label, profile,
            settings: settings ?? const LabelTemplateSettings());
      case PrinterTransport.zpl:
        return ZplDriver().printLabel(label, profile,
            settings: settings ?? const LabelTemplateSettings());
      case PrinterTransport.officePdf:
        return PdfDriver().printLabel(label, profile,
            settings: settings ?? const LabelTemplateSettings());
      case PrinterTransport.escposBluetooth:
      case PrinterTransport.escposUsb:
      case PrinterTransport.escposTcpIp:
        return EscPosDriver().printLabel(label, profile);
    }
  }
}
