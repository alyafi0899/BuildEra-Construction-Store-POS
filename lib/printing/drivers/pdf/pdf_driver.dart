import 'dart:typed_data';
import '../../models/label_template.dart';
import '../../models/print_document.dart';
import '../../models/printer_profile.dart';
import '../../services/label_layout_service.dart';

class PdfDriver {
  final LabelLayoutService labelLayoutService;

  PdfDriver({LabelLayoutService? labelLayoutService})
      : labelLayoutService = labelLayoutService ?? LabelLayoutService();

  PrintResult printReceipt(ReceiptDocument receipt, PrinterProfile profile,
      {required Uint8List bytes}) {
    return PrintResult(
      success: true,
      message: 'Receipt PDF generated',
      bytes: bytes,
      previewText: receipt.title,
    );
  }

  Future<PrintResult> printLabel(LabelDocument label, PrinterProfile profile,
      {required LabelTemplateSettings settings}) async {
    final bytes = await labelLayoutService.buildPdf(label, settings);
    return PrintResult(
      success: true,
      message: 'Office label PDF generated',
      bytes: bytes,
      payload: 'PDF:${label.title}',
      previewText: label.title,
    );
  }
}
