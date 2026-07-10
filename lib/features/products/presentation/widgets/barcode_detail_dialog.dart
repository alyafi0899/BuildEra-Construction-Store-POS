import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as bc;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product.dart';
import '../../../../core/utils/formatters.dart';

class BarcodeDetailDialog extends StatelessWidget {
  final Product product;

  const BarcodeDetailDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showDialog(
      context: context,
      builder: (_) => BarcodeDetailDialog(product: product),
    );
  }

  Future<void> _printLabel() async {
    final doc = pw.Document();
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(product.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                data: product.barcode ?? '',
                barcode: pw.Barcode.ean13(),
                width: 150,
                height: 50,
              ),
              pw.SizedBox(height: 2),
              pw.Text(Formatters.currency(product.basePrice), style: const pw.TextStyle(fontSize: 9)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barcode = product.barcode ?? '';
    final hasBarcode = barcode.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(product.name, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBarcode) ...[
            const Text('Barcode (EAN-13)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            bc.BarcodeWidget(
              data: barcode,
              barcode: bc.Barcode.ean13(),
              width: 200,
              height: 80,
              color: AppTheme.textPrimary,
              drawText: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            const Text('QR Code', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            QrImageView(
              data: barcode,
              version: QrVersions.auto,
              size: 150,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.textPrimary),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.textPrimary),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Produk ini belum memiliki barcode.', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        if (hasBarcode)
          ElevatedButton.icon(
            onPressed: _printLabel,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Cetak Label'),
          ),
      ],
    );
  }
}
