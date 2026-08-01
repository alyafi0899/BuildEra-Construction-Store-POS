import '../../models/label_template.dart';
import '../../models/print_document.dart';
import '../../models/printer_profile.dart';

class TsplDriver {
  PrintResult printLabel(LabelDocument label, PrinterProfile profile,
      {required LabelTemplateSettings settings}) {
    final payload = <String>[
      '^XA',
      '^FO0,0^AD,${settings.storeNameFontSize},${settings.storeNameFontSize}^FD${label.title}^FS',
      ...label.lines.map((line) =>
          '^FO0,0^AD,${line.fontSize},${line.fontSize}^FD${line.text}^FS'),
      '^XZ'
    ].join('\n');
    return PrintResult(
        success: true,
        message: 'TSPL payload generated',
        payload: payload,
        previewText: payload);
  }
}
