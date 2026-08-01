import '../models/print_document.dart';
import '../models/label_template.dart';
import 'label_layout_service.dart';

class PreviewService {
  String renderReceiptPreview(ReceiptDocument receipt) {
    final buffer = StringBuffer();
    buffer.writeln(receipt.title);
    for (final line in receipt.lines) {
      buffer.writeln(line.text);
    }
    return buffer.toString();
  }

  String renderLabelPreview(
      LabelDocument label, LabelTemplateSettings settings) {
    return LabelLayoutService().buildPreview(label, settings);
  }
}
