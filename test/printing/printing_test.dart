import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:buildera/printing/printing.dart';
import 'package:buildera/features/settings/models/store_settings.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/printing/services/bluetooth_printer_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  test('auto-cut off feeds five lines without a cut command', () {
    final bytes = EscPosBuilder(58).build(cut: false);

    expect(bytes, isNot(containsAll([0x1D, 0x56, 0x01])));
    expect(bytes.skip(bytes.length - 5).toList(), [0x0A, 0x0A, 0x0A, 0x0A, 0x0A]);
  });

  test('auto-cut on keeps three feed lines and the cut command', () {
    final bytes = EscPosBuilder(58).build();

    expect(bytes, containsAll([0x1D, 0x56, 0x01]));
    expect(
      bytes.skip(bytes.length - 6).toList(),
      [0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x01],
    );
  });

  test('printer profile autoCut false disables the ESC/POS cut command',
      () {
    final result = EscPosDriver().printReceipt(
      _receiptWithProduct('Pipa'),
      const PrinterProfile(
        id: '58mm',
        name: '58mm',
        transport: PrinterTransport.escposBluetooth,
        paperWidthMm: 58,
        defaults: {'autoCut': false},
      ),
    );

    expect(result.success, isTrue, reason: result.message);
    expect(
      result.bytes!.skip(result.bytes!.length - 5).toList(),
      [0x0A, 0x0A, 0x0A, 0x0A, 0x0A],
    );
  });

  test('Bluetooth print reuses a healthy connection to the same printer',
      () async {
    final transport = _FakeBluetoothPrinterTransport();
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );

    await service.printReceipt(
      address: 'printer-1',
      receipt: _receiptWithProduct('Pipa'),
      profile: _bluetoothProfile(),
    );
    await service.printReceipt(
      address: 'printer-1',
      receipt: _receiptWithProduct('Pipa'),
      profile: _bluetoothProfile(),
    );

    expect(transport.connectCount, 1);
    expect(transport.disconnectCount, 1);
    expect(transport.writeCount, 2);
  });

  test('Bluetooth print reconnects and retries a failed write once',
      () async {
    final transport = _FakeBluetoothPrinterTransport(writeResults: [false, true]);
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );

    await service.printReceipt(
      address: 'printer-1',
      receipt: _receiptWithProduct('Pipa'),
      profile: _bluetoothProfile(),
    );

    expect(transport.connectCount, 2);
    expect(transport.disconnectCount, 2);
    expect(transport.writeCount, 2);
  });

  test('Bluetooth print retries once when the write throws', () async {
    final transport = _FakeBluetoothPrinterTransport(
      writeResults: [Exception('write failed'), true],
    );
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );

    await service.printReceipt(
      address: 'printer-1',
      receipt: _receiptWithProduct('Pipa'),
      profile: _bluetoothProfile(),
    );

    expect(transport.connectCount, 2);
    expect(transport.writeCount, 2);
  });

  test('Bluetooth print throws after one failed retry', () async {
    final transport =
        _FakeBluetoothPrinterTransport(writeResults: [false, false]);
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );

    await expectLater(
      service.printReceipt(
        address: 'printer-1',
        receipt: _receiptWithProduct('Pipa'),
        profile: _bluetoothProfile(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('data struk tidak terkirim'),
        ),
      ),
    );
    expect(transport.connectCount, 2);
    expect(transport.writeCount, 2);
  });
}

PrinterProfile _bluetoothProfile() => const PrinterProfile(
      id: 'bluetooth',
      name: 'Bluetooth',
      transport: PrinterTransport.escposBluetooth,
      paperWidthMm: 58,
    );

class _FakeBluetoothPrinterTransport implements BluetoothPrinterTransport {
  _FakeBluetoothPrinterTransport({List<Object>? writeResults})
      : _writeResults = List.of(writeResults ?? [true]);

  final List<Object> _writeResults;
  bool _connected = false;
  int connectCount = 0;
  int disconnectCount = 0;
  int writeCount = 0;

  @override
  Future<bool> get connectionStatus async => _connected;

  @override
  Future<bool> get bluetoothEnabled async => true;

  @override
  Future<bool> get disconnect async {
    disconnectCount++;
    _connected = false;
    return true;
  }

  @override
  Future<bool> connect({required String macPrinterAddress}) async {
    connectCount++;
    _connected = true;
    return true;
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    writeCount++;
    final result = _writeResults.isEmpty ? true : _writeResults.removeAt(0);
    if (result is Exception) throw result;
    return result as bool;
  }
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
