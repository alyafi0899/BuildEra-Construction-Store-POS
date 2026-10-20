import 'dart:convert';
import 'dart:math' as math;

import '../../models/label_template.dart';
import '../../models/print_document.dart';
import '../../models/printer_profile.dart';

class ZplDriver {
  PrintResult printLabel(LabelDocument label, PrinterProfile profile,
      {required LabelTemplateSettings settings}) {
    final items = label.metadata['items'];
    final payload = items is List && items.isNotEmpty
        ? items
            .whereType<Map>()
            .map((item) => _buildItem(label, settings, item))
            .join('\n')
        : _buildItem(label, settings, null);
    return PrintResult(
        success: true,
        message: 'ZPL payload generated',
        payload: payload,
        bytes: utf8.encode(payload),
        previewText: payload);
  }

  String _buildItem(
    LabelDocument label,
    LabelTemplateSettings settings,
    Map? item,
  ) {
    final storeName = _safe(item?['businessName'] ?? label.title);
    final productName = _safe(item?['productName'] ?? '');
    final barcode = _safe(item?['barcode'] ?? label.barcode ?? '');
    final price = _safe(item?['price'] ?? '');
    final barcodeHeight = math.max(40, (settings.barcodeHeightMm * 8).round());
    final productY = math.max(28, (settings.storeNameFontSize * 4).round());
    final barcodeY = productY + 28;
    final priceY = barcodeY + barcodeHeight + 12;
    final commands = <String>[
      '^XA',
      '^PW${(settings.labelWidthMm * 8).round()}',
      '^LL${(settings.labelHeightMm * 8).round()}',
      '^FO16,8^A0N,24,24^FD$storeName^FS',
      if (productName.isNotEmpty) '^FO16,$productY^A0N,24,24^FD$productName^FS',
      if (barcode.isNotEmpty) ...[
        '^BY2',
        '^FO16,$barcodeY^BCN,$barcodeHeight,Y,N,N^FD$barcode^FS',
      ],
      if (barcode.isNotEmpty) '^FO16,$priceY^A0N,18,18^FD$barcode^FS',
      if (price.isNotEmpty) '^FO16,${priceY + 22}^A0N,24,24^FD$price^FS',
      ...label.lines.map(
        (line) =>
            '^FO16,${priceY + 48}^A0N,${line.fontSize * 2},${line.fontSize * 2}^FD${_safe(line.text)}^FS',
      ),
      '^XZ',
    ];
    return commands.join('\n');
  }

  String _safe(Object value) =>
      value.toString().replaceAll('^', ' ').replaceAll('~', ' ');
}
