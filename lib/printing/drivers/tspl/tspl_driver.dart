import 'dart:convert';
import 'dart:math' as math;

import '../../models/label_template.dart';
import '../../models/print_document.dart';
import '../../models/printer_profile.dart';

class TsplDriver {
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
        message: 'TSPL payload generated',
        payload: payload,
        bytes: utf8.encode(payload),
        previewText: payload);
  }

  String _buildItem(
    LabelDocument label,
    LabelTemplateSettings settings,
    Map? item,
  ) {
    final width = settings.labelWidthMm.toStringAsFixed(1);
    final height = settings.labelHeightMm.toStringAsFixed(1);
    final gap = settings.verticalGapMm.toStringAsFixed(1);
    final storeName = _safe(item?['businessName'] ?? label.title);
    final productName = _safe(item?['productName'] ?? '');
    final barcode = _safe(item?['barcode'] ?? label.barcode ?? '');
    final price = _safe(item?['price'] ?? '');
    final barcodeHeight = math.max(8, settings.barcodeHeightMm.round());
    final commands = <String>[
      'SIZE $width mm,$height mm',
      'GAP $gap mm,0',
      'CLS',
      'TEXT 16,8,"3",0,1,1,"$storeName"',
      if (productName.isNotEmpty) 'TEXT 16,36,"3",0,1,1,"$productName"',
      if (barcode.isNotEmpty)
        'BARCODE 16,68,"128",$barcodeHeight,1,0,2,2,"$barcode"',
      if (barcode.isNotEmpty)
        'TEXT 16,${78 + barcodeHeight},"3",0,1,1,"$barcode"',
      if (price.isNotEmpty) 'TEXT 16,${102 + barcodeHeight},"3",0,1,1,"$price"',
      ...label.lines.map((line) =>
          'TEXT 16,${126 + barcodeHeight},"3",0,1,1,"${_safe(line.text)}"'),
      'PRINT 1,1',
    ];
    return commands.join('\r\n');
  }

  String _safe(Object value) => value
      .toString()
      .replaceAll('"', "'")
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ');
}
