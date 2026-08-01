import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/printing/printing.dart';

void main() {
  test('receipt layout service builds a printable PDF payload', () async {
    final receipt = ReceiptDocument(
      title: 'BuildEra POS',
      lines: const [
        ReceiptLine(text: 'Kasir: Admin'),
        ReceiptLine(text: 'Total: 100.000'),
      ],
    );

    final result = await PrintOrchestrator().buildReceiptPdf(
      receipt,
      const PrinterProfile(
        id: 'default',
        name: 'Default',
        transport: PrinterTransport.officePdf,
        paperWidthMm: 80,
        paperHeightMm: 0,
        marginMm: 2,
      ),
    );

    expect(result.success, isTrue);
    expect(result.bytes, isNotNull);
    expect(result.bytes!.isNotEmpty, isTrue);
  });

  test('thermal label driver emits TSPL content', () async {
    final label = LabelDocument(
      title: 'LABEL',
      lines: const [LabelLine(text: 'SKU-001')],
    );

    final result = await PrintOrchestrator().printLabel(
      label,
      const PrinterProfile(
        id: 'tspl',
        name: 'TSPL',
        transport: PrinterTransport.tspl,
      ),
    );

    expect(result.success, isTrue);
    expect(result.payload, contains('^XA'));
    expect(result.payload, contains('SKU-001'));
  });

  test('office label print flow generates PDF bytes', () async {
    final label = LabelDocument(
      title: 'LABEL',
      lines: const [LabelLine(text: 'SKU-001')],
      metadata: {
        'businessName': 'BuildEra',
        'productName': 'Test Product',
        'barcode': '123456789',
        'price': '100.000',
      },
    );

    final result = await PrintOrchestrator().printLabel(
      label,
      const PrinterProfile(
        id: 'office',
        name: 'Office',
        transport: PrinterTransport.officePdf,
      ),
      settings: const LabelTemplateSettings(),
    );

    expect(result.success, isTrue);
    expect(result.bytes, isNotNull);
    expect(result.bytes!.isNotEmpty, isTrue);
  });
}
