import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/label_template.dart';
import '../models/print_document.dart';

class LabelLayoutService {
  String buildPreview(LabelDocument document, LabelTemplateSettings settings) {
    final buffer = StringBuffer();
    buffer.writeln(document.title);
    for (final line in document.lines) {
      buffer.writeln(line.text);
    }
    return buffer.toString();
  }

  Future<Uint8List> buildPdf(
    LabelDocument document,
    LabelTemplateSettings settings,
  ) async {
    final pdf = pw.Document();
    final items = _extractItems(document);
    if (items.isEmpty) {
      return Uint8List(0);
    }

    final isRollMode = document.metadata['isRollMode'] == true;
    final labelWidthMm =
        (document.metadata['labelWidthMm'] ?? settings.labelWidthMm).toDouble();
    final labelHeightMm =
        (document.metadata['labelHeightMm'] ?? settings.labelHeightMm)
            .toDouble();
    final horizontalGapMm =
        (document.metadata['horizontalGapMm'] ?? settings.horizontalGapMm)
            .toDouble();
    final verticalGapMm =
        (document.metadata['verticalGapMm'] ?? settings.verticalGapMm)
            .toDouble();
    final labelPaddingMm =
        (document.metadata['labelPaddingMm'] ?? settings.labelPaddingMm)
            .toDouble();
    final int columns = (document.metadata['columns'] ?? settings.columns).toInt();
    final paperWidthMm =
        (document.metadata['paperWidthMm'] ?? settings.paperWidthMm).toDouble();
    final paperHeightMm =
        (document.metadata['paperHeightMm'] ?? settings.paperHeightMm)
            .toDouble();
    final paperMarginMm =
        (document.metadata['paperMarginMm'] ?? settings.paperMarginMm)
            .toDouble();
    final barcodeWidthMm =
        (document.metadata['barcodeWidthMm'] ?? settings.barcodeWidthMm)
            .toDouble();
    final barcodeHeightMm =
        (document.metadata['barcodeHeightMm'] ?? settings.barcodeHeightMm)
            .toDouble();
    final storeNameFontSize =
        (document.metadata['storeNameFontSize'] ?? settings.storeNameFontSize)
            .toDouble();
    final productNameFontSize = (document.metadata['productNameFontSize'] ??
            settings.productNameFontSize)
        .toDouble();
    final barcodeNumberFontSize = (document.metadata['barcodeNumberFontSize'] ??
            settings.barcodeNumberFontSize)
        .toDouble();
    final priceFontSize =
        (document.metadata['priceFontSize'] ?? settings.priceFontSize)
            .toDouble();

    const double mmToPt = 2.83465;

    if (isRollMode) {
      final rollWidth =
          (labelWidthMm * columns) + (horizontalGapMm * (columns - 1));
      // Thermal printers expect the page height to be the exact label height (pitch).
      // The printer hardware sensor handles the physical gap.
      final rollFormat = PdfPageFormat(
        rollWidth * mmToPt,
        labelHeightMm * mmToPt,
        marginAll: 0,
      );

      for (var i = 0; i < items.length; i += columns) {
        final pageItems = items.skip(i).take(columns).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: rollFormat,
            build: (context) {
              return pw.Wrap(
                spacing: horizontalGapMm * mmToPt,
                children: pageItems
                    .map((item) => _buildLabel(
                        item,
                        labelWidthMm,
                        labelHeightMm,
                        labelPaddingMm,
                        barcodeWidthMm,
                        barcodeHeightMm,
                        storeNameFontSize,
                        productNameFontSize,
                        barcodeNumberFontSize,
                        priceFontSize,
                        mmToPt))
                    .toList(),
              );
            },
          ),
        );
      }
    } else {
      final pageFormat = PdfPageFormat(
        paperWidthMm * mmToPt,
        paperHeightMm * mmToPt,
        marginAll: paperMarginMm * mmToPt,
      );
      final int labelsPerPage = columns *
          ((pageFormat.availableHeight / (labelHeightMm * mmToPt)).floor());

      for (var i = 0; i < items.length; i += labelsPerPage) {
        final pageItems = items.skip(i).take(labelsPerPage).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              return pw.Wrap(
                spacing: horizontalGapMm * mmToPt,
                runSpacing: verticalGapMm * mmToPt,
                children: pageItems
                    .map((item) => _buildLabel(
                        item,
                        labelWidthMm,
                        labelHeightMm,
                        labelPaddingMm,
                        barcodeWidthMm,
                        barcodeHeightMm,
                        storeNameFontSize,
                        productNameFontSize,
                        barcodeNumberFontSize,
                        priceFontSize,
                        mmToPt))
                    .toList(),
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  List<Map<String, dynamic>> _extractItems(LabelDocument document) {
    final explicitItems = document.metadata['items'];
    if (explicitItems is List) {
      return explicitItems.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return {'text': item.toString()};
      }).toList();
    }

    return [
      {
        'businessName': document.metadata['businessName'] ?? '',
        'productName': document.metadata['productName'] ?? document.title,
        'barcode': document.metadata['barcode'] ?? document.barcode ?? '',
        'price': document.metadata['price'] ?? '',
        'lines': document.lines.map((line) => line.text).toList(),
      }
    ];
  }

  pw.Widget _buildLabel(
    Map<String, dynamic> item,
    double labelWidthMm,
    double labelHeightMm,
    double labelPaddingMm,
    double barcodeWidthMm,
    double barcodeHeightMm,
    double storeNameFontSize,
    double productNameFontSize,
    double barcodeNumberFontSize,
    double priceFontSize,
    double mmToPt,
  ) {
    final businessName = (item['businessName'] ?? '').toString();
    final productName = (item['productName'] ?? '').toString();
    final barcodeValue = (item['barcode'] ?? '').toString();
    final price = (item['price'] ?? '').toString();

    final barcode = Barcode.code128();

    return pw.SizedBox(
      width: labelWidthMm * mmToPt,
      height: labelHeightMm * mmToPt,
      child: pw.Container(
        padding: pw.EdgeInsets.all(labelPaddingMm * mmToPt),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (businessName.isNotEmpty)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(
                      fontSize: storeNameFontSize,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            if (businessName.isNotEmpty) pw.SizedBox(height: 2),
            if (productName.isNotEmpty)
              pw.Text(
                productName,
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                    fontSize: productNameFontSize,
                    fontWeight: pw.FontWeight.bold),
              ),
            pw.Spacer(),
            if (barcodeValue.isNotEmpty)
              pw.SizedBox(
                height: barcodeHeightMm * mmToPt,
                width: barcodeWidthMm * mmToPt,
                child: pw.BarcodeWidget(
                  barcode: barcode,
                  data: barcodeValue,
                  drawText: false,
                  color: PdfColors.black,
                ),
              ),
            if (barcodeValue.isNotEmpty) pw.SizedBox(height: 2),
            if (barcodeValue.isNotEmpty)
              pw.Text(
                barcodeValue,
                style: pw.TextStyle(
                    fontSize: barcodeNumberFontSize, letterSpacing: 1),
              ),
            pw.Spacer(),
            if (price.isNotEmpty)
              pw.Text(
                price,
                style: pw.TextStyle(
                    fontSize: priceFontSize, fontWeight: pw.FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
