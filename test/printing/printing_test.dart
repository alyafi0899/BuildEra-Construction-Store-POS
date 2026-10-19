import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:buildera/printing/printing.dart';
import 'package:buildera/features/settings/models/store_settings.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  test('receipt layout service builds a printable PDF payload', () async {
    final receipt = ReceiptDocument(
      title: 'BuildEra POS',
      lines: const [
        ReceiptLine(text: 'Kasir: Admin'),
        ReceiptLine(text: 'Total: 100.000'),
      ],
      metadata: const {
        'settings': StoreSettings(businessName: 'BuildEra Store'),
      },
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
      metadata: const {
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

  test('printer sanitizer replaces special characters with ASCII', () {
    expect(
      sanitizeForPrinter('–—‘’“”•…×\u00A0\t'),
      '--\'\'""*...x  ',
    );
    final sanitized = sanitizeForPrinter('– “kutip” • … é 😀');
    expect(sanitized, '- "kutip" * ... ? ?');
    expect(sanitized.codeUnits.every((codeUnit) => codeUnit < 0x80), isTrue);
  });

  test('ESC/POS text emits ASCII bytes for special characters', () {
    final builder = EscPosBuilder(58);
    builder.text('– “kutip” • … é 😀');

    expect(builder.build().every((byte) => byte < 0x80), isTrue);
  });

  test('wrapped product names stay within printer width after sanitizing', () {
    final name58 = '…' * 32;
    final receipt58 = _receiptWithProduct(name58);
    final result58 = EscPosDriver().printReceipt(
      receipt58,
      const PrinterProfile(
        id: '58mm',
        name: '58mm',
        transport: PrinterTransport.escposBluetooth,
        paperWidthMm: 58,
      ),
    );
    expect(result58.success, isTrue);
    expect(
      result58.bytes,
      containsAll(_asciiLine('...' * 10 + '..')),
    );

    final name80 = '…' * 49;
    final result80 = EscPosDriver().printReceipt(
      _receiptWithProduct(name80),
      const PrinterProfile(
        id: '80mm',
        name: '80mm',
        transport: PrinterTransport.escposBluetooth,
        paperWidthMm: 80,
      ),
    );
    expect(result80.success, isTrue);
    expect(result80.bytes, containsAll(_asciiLine('.' * 48)));
  });

  test('complete ESC/POS receipt succeeds with special product characters', () {
    final result = EscPosDriver().printReceipt(
      _receiptWithProduct('Pipa – “Premium” • ½ … é 😀'),
      const PrinterProfile(
        id: '58mm',
        name: '58mm',
        transport: PrinterTransport.escposBluetooth,
        paperWidthMm: 58,
      ),
    );

    expect(result.success, isTrue, reason: result.message);
    expect(result.bytes, isNotNull);
    expect(result.bytes!.every((byte) => byte < 0x80), isTrue);
  });
}

ReceiptDocument _receiptWithProduct(String productName) {
  final now = DateTime(2026, 1, 1);
  return ReceiptDocument(
    title: 'Test',
    lines: const [],
    metadata: {
      'settings': const StoreSettings(businessName: 'BuildEra'),
      'transaction': Transaction(
        id: 'tx-1',
        invoiceNumber: 'INV-1',
        subtotal: 1000,
        itemDiscountTotal: 0,
        transDiscountValue: 0,
        transDiscountType: DiscountType.fixed,
        transDiscountAmount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 1000,
        paymentMethod: 'Tunai',
        amountPaid: 1000,
        changeAmount: 0,
        createdAt: now,
        updatedAt: now,
        items: [
          TransactionItem(
            id: 'item-1',
            transactionId: 'tx-1',
            productId: 'product-1',
            productName: productName,
            unitName: 'pcs',
            conversionRate: 1,
            quantity: 1,
            costPrice: 500,
            originalPrice: 1000,
            soldPrice: 1000,
            discountValue: 0,
            discountType: DiscountType.fixed,
            subtotal: 1000,
          ),
        ],
      ),
    },
  );
}

List<int> _asciiLine(String text) => [...text.codeUnits, 0x0A];
