import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:buildera/printing/printing.dart';
import 'package:buildera/core/constants/app_constants.dart';
import 'package:buildera/features/settings/models/store_settings.dart';
import 'package:buildera/features/debts/models/customer.dart';
import 'package:buildera/features/debts/models/debt.dart';
import 'package:buildera/features/debts/models/debt_payment.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/printing/services/bluetooth_printer_service.dart';
import 'package:buildera/core/utils/image_helper.dart';

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
    expect(result.payload, contains('SIZE 40.0 mm,30.0 mm'));
    expect(result.payload, contains('SKU-001'));
    expect(result.bytes, isNotEmpty);
  });

  test('ZPL label driver emits barcode commands and raw bytes', () async {
    final result = await PrintOrchestrator().printLabel(
      LabelDocument(
        title: 'LABEL',
        lines: const [],
        metadata: const {
          'items': [
            {
              'businessName': 'BuildEra',
              'productName': 'Pipa',
              'barcode': '123456789012',
              'price': 'Rp. 10.000',
            },
          ],
        },
      ),
      const PrinterProfile(
        id: 'zpl',
        name: 'ZPL',
        transport: PrinterTransport.zpl,
        address: 'printer-1',
      ),
    );

    expect(result.success, isTrue);
    expect(result.payload, contains('^BC'));
    expect(result.payload, contains('123456789012'));
    expect(result.bytes, isNotEmpty);
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

  test('ESC/POS raster emits correctly sized GS v 0 data', () {
    final image = img.Image(width: 4, height: 2);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
    final builder = EscPosBuilder(58)
      ..imageRaster(
        Uint8List.fromList(img.encodePng(image)),
        maxWidthDots: 40,
      );

    final bytes = builder.build();
    final headerIndex = _indexOfBytes(bytes, [0x1D, 0x76, 0x30, 0x00]);

    expect(headerIndex, isNonNegative);
    expect(bytes.sublist(headerIndex + 4, headerIndex + 8), [1, 0, 2, 0]);
    expect(bytes.sublist(headerIndex + 8, headerIndex + 10), isNotEmpty);
  });

  test('ESC/POS raster is omitted for missing or invalid image data', () {
    final emptyBuilder = EscPosBuilder(58);
    final invalidBuilder = EscPosBuilder(58)
      ..imageRaster(
        Uint8List.fromList([1, 2, 3]),
        maxWidthDots: 384,
      );

    expect(_indexOfBytes(emptyBuilder.build(), [0x1D, 0x76, 0x30]), -1);
    expect(_indexOfBytes(invalidBuilder.build(), [0x1D, 0x76, 0x30]), -1);
  });

  test('QR raster uses thresholding and keeps the requested white margin', () {
    final image = img.Image(width: 32, height: 32);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
    final builder = EscPosBuilder(58)
      ..imageRaster(
        Uint8List.fromList(img.encodePng(image)),
        maxWidthDots: 40,
        maxHeightDots: 32,
        marginDots: 8,
      );
    final bytes = builder.build();
    final headerIndex = _indexOfBytes(bytes, [0x1D, 0x76, 0x30, 0x00]);

    expect(headerIndex, isNonNegative);
    final bytesPerRow = bytes[headerIndex + 4];
    final rasterHeight = bytes[headerIndex + 6];
    expect(bytesPerRow * 8, lessThanOrEqualTo(40));
    expect(rasterHeight, 32);

    final raster = bytes.sublist(
      headerIndex + 8,
      headerIndex + 8 + bytesPerRow * rasterHeight,
    );
    expect(raster.take(bytesPerRow * 8), everyElement(0));
    expect(raster.skip(bytesPerRow * 24), everyElement(0));
    for (var row = 8; row < 24; row++) {
      final rowBytes =
          raster.sublist(row * bytesPerRow, (row + 1) * bytesPerRow);
      expect(rowBytes.first, 0);
      expect(rowBytes[1], 0xFF);
      expect(rowBytes[2], 0xFF);
      expect(rowBytes.last & 0x0F, 0);
      final bits = [
        for (final byte in rowBytes)
          for (var bit = 7; bit >= 0; bit--) (byte >> bit) & 1,
      ];
      expect(bits.every((bit) => bit == 0 || bit == 1), isTrue);
    }
  });

  test('QR raster upscales small QR images for usable thermal output', () {
    final image = img.Image(width: 16, height: 16);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, (x + y).isEven ? 0 : 255,
            (x + y).isEven ? 0 : 255, (x + y).isEven ? 0 : 255);
      }
    }
    final builder = EscPosBuilder(58)
      ..imageRaster(
        Uint8List.fromList(img.encodePng(image)),
        maxWidthDots: 384,
        maxHeightDots: 288,
        marginDots: 8,
        allowUpscale: true,
      );
    final bytes = builder.build();
    final headerIndex = _indexOfBytes(bytes, [0x1D, 0x76, 0x30, 0x00]);

    expect(headerIndex, isNonNegative);
    expect(bytes[headerIndex + 4], 36);
    expect(
      bytes[headerIndex + 6] + (bytes[headerIndex + 7] << 8),
      288,
    );
    expect(bytes.length, greaterThan(10 * 1024));
  });

  test('QR image processing preserves lossless PNG data', () {
    final source = img.Image(width: 32, height: 32);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, (x + y).isEven ? 0 : 255,
            (x + y).isEven ? 0 : 255, (x + y).isEven ? 0 : 255);
      }
    }

    final processed = ImageHelper.processQrImage(
      Uint8List.fromList(img.encodeJpg(source, quality: 95)),
    );
    final decoded = img.decodeImage(processed);

    expect(processed.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(decoded?.width, 32);
    expect(decoded?.height, 32);
  });

  test('receipt appends logo and QR raster data to its single ESC/POS job', () {
    final image = img.Image(width: 4, height: 4);
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final receipt = ReceiptDocument(
      title: 'BuildEra',
      lines: const [],
      metadata: {
        'settings': const StoreSettings(businessName: 'BuildEra'),
        'transaction': _receiptWithProduct('Pipa').metadata['transaction'],
        'logoBytes': pngBytes,
        'qrisBytes': pngBytes,
      },
    );

    final result = EscPosDriver().printReceipt(receipt, _bluetoothProfile());

    expect(result.success, isTrue, reason: result.message);
    expect(
        _indexOfBytes(result.bytes!, [0x1D, 0x76, 0x30, 0x00]), isNonNegative);
  });

  test('Debit receipts include configured bank account details', () {
    final result = EscPosDriver().printReceipt(
      _receiptWithProduct(
        'Pipa',
        paymentMethod: AppConstants.paymentDebit,
        settings: const StoreSettings(
          businessName: 'BuildEra',
          bankAccounts: [
            BankAccount(
              bankName: 'Bank Contoh',
              accountNumber: '123456',
              accountHolder: 'Toko BuildEra',
            ),
          ],
        ),
      ),
      _bluetoothProfile(),
    );

    expect(result.success, isTrue, reason: result.message);
    expect(
      _containsBytes(result.bytes!, _asciiLine('Bank Contoh: 123456')),
      isTrue,
    );
  });

  test('debt receipt information uses the debt creation date', () {
    final createdAt = DateTime(2024, 2, 3, 14, 5);
    final receipt = ReceiptDocument(
      title: 'NOTA PIUTANG',
      lines: const [],
      metadata: {
        'settings': const StoreSettings(businessName: 'BuildEra'),
        'customer': Customer(
          id: 'customer-1',
          name: 'Pelanggan',
          phone: '',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        'debt': Debt(
          id: 'debt-1',
          transactionId: 'tx-1',
          customerId: 'customer-1',
          customerName: 'Pelanggan',
          invoiceNumber: 'INV-PIUTANG',
          totalAmount: 1000,
          paidAmount: 0,
          remainingBalance: 1000,
          dueDate: DateTime(2024, 3, 3),
          createdAt: createdAt,
          updatedAt: createdAt,
          status: DebtStatus.unpaid,
        ),
      },
    );

    final result = EscPosDriver().printReceipt(receipt, _bluetoothProfile());

    expect(result.success, isTrue, reason: result.message);
    expect(_containsBytes(result.bytes!, _asciiLine('03/02/2024')), isTrue);
  });

  test('cash receipt has the established text snapshot and optional customer',
      () {
    final withoutCustomer = EscPosDriver().printReceipt(
      _receiptWithProduct('Pipa'),
      _bluetoothProfile(),
    );
    final snapshot = _receiptTextLines(withoutCustomer.bytes!);

    expect(
      snapshot.take(snapshot.length - 1).toList(),
      [
        'BUILDERA',
        '--------------------------------',
        'Kasir : Kasir Uji     01/01/2026',
        'No    : INV-1              00:00',
        '--------------------------------',
        'Pipa',
        '1 pcs x Rp 1.000        Rp 1.000',
        '--------------------------------',
        'Subtotal                Rp 1.000',
        'TOTAL  Rp 1.000',
        '--------------------------------',
        'Bayar (Tunai)           Rp 1.000',
        'Kembalian                   Rp 0',
        'Terima Kasih atas Kunjungan Anda',
      ],
    );
    expect(snapshot, contains('Pipa'));
    expect(snapshot.any((line) => line.startsWith('Waktu Cetak: ')), isTrue);
    expect(snapshot.any((line) => line.startsWith('Plg   :')), isFalse);
    expect(_indexOfBytes(withoutCustomer.bytes!, [0x1D, 0x76, 0x30]), -1);

    final withCustomer = EscPosDriver().printReceipt(
      _receiptWithProduct(
        'Pipa',
        customerName: 'Nama Pelanggan',
      ),
      _bluetoothProfile(),
    );
    expect(_receiptTextLines(withCustomer.bytes!),
        contains('Plg   : Nama Pelanggan'));
  });

  test('Debit and Transfer Bank receipts include store bank accounts', () {
    const settings = StoreSettings(
      businessName: 'BuildEra',
      bankAccounts: [
        BankAccount(
          bankName: 'Bank Contoh',
          accountNumber: '123456',
          accountHolder: 'Toko BuildEra',
        ),
      ],
    );
    for (final method in [
      AppConstants.paymentDebit,
      AppConstants.paymentTransfer,
    ]) {
      final result = EscPosDriver().printReceipt(
        _receiptWithProduct('Pipa', paymentMethod: method, settings: settings),
        _bluetoothProfile(),
      );
      final lines = _receiptTextLines(result.bytes!);

      expect(result.success, isTrue, reason: result.message);
      expect(lines, contains('INFORMASI PEMBAYARAN TRANSFER'));
      expect(lines, contains('Bank Contoh: 123456'));
      expect(lines, contains('a/n Toko BuildEra'));
    }
  });

  test('QRIS receipt prints prompt and raster only when image bytes exist', () {
    final image = img.Image(width: 16, height: 16);
    final qrisBytes = Uint8List.fromList(img.encodePng(image));
    final withQris = EscPosDriver().printReceipt(
      _receiptWithProduct(
        'Pipa',
        paymentMethod: AppConstants.paymentQris,
        extraMetadata: {'qrisBytes': qrisBytes},
      ),
      _bluetoothProfile(),
    );
    final withoutQris = EscPosDriver().printReceipt(
      _receiptWithProduct(
        'Pipa',
        paymentMethod: AppConstants.paymentQris,
      ),
      _bluetoothProfile(),
    );

    expect(_receiptTextLines(withQris.bytes!),
        contains('Scan QRIS untuk membayar'));
    expect(_indexOfBytes(withQris.bytes!, [0x1D, 0x76, 0x30]), isNonNegative);
    expect(_receiptTextLines(withoutQris.bytes!),
        isNot(contains('Scan QRIS untuk membayar')));
    expect(_indexOfBytes(withoutQris.bytes!, [0x1D, 0x76, 0x30]), -1);
  });

  test('debt receipt includes bill title, totals, history, bank and QR', () {
    final createdAt = DateTime(2024, 2, 3, 14, 5);
    final image = img.Image(width: 16, height: 16);
    final receipt = _debtReceipt(
      createdAt: createdAt,
      qrisBytes: Uint8List.fromList(img.encodePng(image)),
      paymentHistory: [
        DebtPayment(
          id: 'payment-1',
          debtId: 'debt-1',
          customerId: 'customer-1',
          amount: 250,
          createdAt: DateTime(2024, 2, 4),
        ),
      ],
    );
    final result = EscPosDriver().printReceipt(receipt, _bluetoothProfile());
    final lines = _receiptTextLines(result.bytes!);

    expect(result.success, isTrue, reason: result.message);
    expect(lines, contains('STRUK TAGIHAN'));
    expect(_containsBytes(result.bytes!, _asciiLine('03/02/2024')), isTrue);
    expect(lines, contains('Kasir: Kasir Uji'));
    expect(lines, contains('Bank Contoh: 123456'));
    expect(lines, contains('Scan QRIS untuk membayar'));
    expect(_indexOfBytes(result.bytes!, [0x1D, 0x76, 0x30]), isNonNegative);
    expect(lines.any((line) => line.startsWith('Total Sudah Bayar')), isTrue);
    expect(lines.any((line) => line.startsWith('SISA PIUTANG')), isTrue);
    expect(lines, contains('RIWAYAT CICILAN / PEMBAYARAN'));
    expect(lines, contains('Dokumen ini adalah bukti sah piutang'));
    expect(lines.any((line) => line.startsWith('Waktu Cetak: ')), isTrue);
  });

  test('logo raster is the first raster command in the receipt', () {
    final image = img.Image(width: 8, height: 4);
    final logoBytes = Uint8List.fromList(img.encodePng(image));
    final result = EscPosDriver().printReceipt(
      _receiptWithProduct('Pipa', extraMetadata: {'logoBytes': logoBytes}),
      _bluetoothProfile(),
    );
    final bytes = result.bytes!;
    final logoIndex = _indexOfBytes(bytes, [0x1D, 0x76, 0x30, 0x00]);
    final businessNameIndex = _indexOfBytes(bytes, 'BUILDERA'.codeUnits);

    expect(result.success, isTrue, reason: result.message);
    expect(logoIndex, greaterThanOrEqualTo(0));
    expect(businessNameIndex, greaterThan(logoIndex));
    expect(bytes.every((byte) => byte >= 0 && byte < 256), isTrue);
  });

  test('customer name is wrapped and receipt lines fit printer columns', () {
    final result = EscPosDriver().printReceipt(
      _receiptWithProduct(
        'Pipa',
        customerName: 'Pelanggan Bangunan Berskala Sangat Panjang Sekali',
      ),
      _bluetoothProfile(),
    );

    expect(result.success, isTrue, reason: result.message);
    expect(
      _receiptTextLines(result.bytes!).every((line) => line.length <= 32),
      isTrue,
    );
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
    expect(
        bytes.skip(bytes.length - 5).toList(), [0x0A, 0x0A, 0x0A, 0x0A, 0x0A]);
  });

  test('auto-cut on keeps three feed lines and the cut command', () {
    final bytes = EscPosBuilder(58).build();

    expect(bytes, containsAll([0x1D, 0x56, 0x01]));
    expect(
      bytes.skip(bytes.length - 6).toList(),
      [0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x01],
    );
  });

  test('printer profile autoCut false disables the ESC/POS cut command', () {
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

  test('Bluetooth receipt sends one ordinary List<int> write job', () async {
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

    expect(transport.writeCount, 1);
    expect(transport.lastWrite, isNot(isA<Uint8List>()));
    expect(transport.lastWrite, isNotEmpty);
  });

  test('Bluetooth raw print sends UTF-8 bytes in one ordinary List<int> job',
      () async {
    final transport = _FakeBluetoothPrinterTransport();
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );
    final expected = Uint8List.fromList(utf8.encode('LABEL'));

    await service.printRaw('printer-1', expected);

    expect(transport.writeCount, 1);
    expect(transport.lastWrite, isNot(isA<Uint8List>()));
    expect(transport.lastWrite, expected);
  });

  test('Bluetooth print reconnects and retries a failed write once', () async {
    final transport =
        _FakeBluetoothPrinterTransport(writeResults: [false, true]);
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

  group('Bluetooth permissions on Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('requests connect and scan permissions before connecting', () async {
      final transport = _FakeBluetoothPrinterTransport(
        permissionStatuses: {
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.bluetoothScan: PermissionStatus.granted,
        },
      );
      final service = BluetoothPrinterService(transport: transport);

      await service.connectPrinter('printer-1');

      expect(
        transport.requestedPermissions,
        [Permission.bluetoothConnect, Permission.bluetoothScan],
      );
      expect(transport.connectCount, 1);
    });

    test('reports denied nearby-device permission, not Bluetooth-off',
        () async {
      final transport = _FakeBluetoothPrinterTransport(
        bluetoothIsEnabled: false,
        permissionStatuses: {
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.bluetoothScan: PermissionStatus.denied,
        },
      );
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                'Izin Perangkat Sekitar diperlukan untuk memilih dan '
                    'menghubungkan printer Bluetooth.',
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('Bluetooth ponsel sedang mati')),
              ),
        ),
      );
      expect(transport.connectCount, 0);
    });

    test('explains how to restore permanently denied nearby-device access',
        () async {
      final transport = _FakeBluetoothPrinterTransport(
        permissionStatuses: {
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          Permission.bluetoothScan: PermissionStatus.granted,
        },
      );
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Izin Perangkat Sekitar ditolak permanen. Buka Pengaturan '
                'aplikasi > Izin > Perangkat sekitar, lalu izinkan untuk '
                'BuildEra.',
          ),
        ),
      );
      expect(transport.connectCount, 0);
    });

    test('reports Bluetooth off only after both permissions are confirmed',
        () async {
      final transport = _FakeBluetoothPrinterTransport(
        bluetoothIsEnabled: false,
        permissionStatuses: {
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.bluetoothScan: PermissionStatus.granted,
        },
      );
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Bluetooth ponsel sedang mati. Aktifkan Bluetooth lalu coba lagi.',
          ),
        ),
      );
      expect(transport.connectCount, 0);
    });

    test('checks the printer plugin permission safeguard', () async {
      final transport = _FakeBluetoothPrinterTransport(
        permissionBluetoothGranted: false,
        permissionStatuses: {
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.bluetoothScan: PermissionStatus.granted,
        },
      );
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Izin Perangkat Sekitar diperlukan'),
          ),
        ),
      );
      expect(transport.connectCount, 0);
    });

    test('distinguishes a printer missing from the paired list', () async {
      final transport = _FakeBluetoothPrinterTransport(pairedPrinters: []);
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Printer tidak ditemukan di daftar perangkat Bluetooth'),
          ),
        ),
      );
      expect(transport.connectCount, 0);
    });

    test('provides troubleshooting guidance when connection fails', () async {
      final transport = _FakeBluetoothPrinterTransport(connectResult: false);
      final service = BluetoothPrinterService(transport: transport);

      await expectLater(
        service.connectPrinter('printer-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Tidak dapat terhubung ke printer. Pastikan printer menyala, '
                'berada di dekat ponsel, dan tidak sedang terhubung ke '
                'aplikasi lain (misalnya Thermer). Tutup aplikasi lain yang '
                'memakai printer, lalu coba lagi. Bila masih gagal, hapus '
                'pasangan printer di Pengaturan Bluetooth lalu pasangkan '
                'ulang.',
          ),
        ),
      );
    });
  });
}

PrinterProfile _bluetoothProfile() => const PrinterProfile(
      id: 'bluetooth',
      name: 'Bluetooth',
      transport: PrinterTransport.escposBluetooth,
      paperWidthMm: 58,
    );

class _FakeBluetoothPrinterTransport implements BluetoothPrinterTransport {
  _FakeBluetoothPrinterTransport({
    List<Object>? writeResults,
    Map<Permission, PermissionStatus>? permissionStatuses,
    this.bluetoothIsEnabled = true,
    this.permissionBluetoothGranted = true,
    List<BluetoothInfo>? pairedPrinters,
    this.connectResult = true,
  })  : _writeResults = List.of(writeResults ?? [true]),
        _permissionStatuses = permissionStatuses ??
            {
              Permission.bluetoothConnect: PermissionStatus.granted,
              Permission.bluetoothScan: PermissionStatus.granted,
            },
        _pairedPrinters = pairedPrinters ??
            [BluetoothInfo(name: 'Printer', macAdress: 'printer-1')];

  final List<Object> _writeResults;
  final Map<Permission, PermissionStatus> _permissionStatuses;
  final List<BluetoothInfo> _pairedPrinters;
  final List<Permission> requestedPermissions = [];
  final bool bluetoothIsEnabled;
  final bool permissionBluetoothGranted;
  final bool connectResult;
  bool _connected = false;
  int connectCount = 0;
  int disconnectCount = 0;
  int writeCount = 0;
  List<int>? lastWrite;

  @override
  Future<bool> get connectionStatus async => _connected;

  @override
  Future<bool> get bluetoothEnabled async => bluetoothIsEnabled;

  @override
  Future<bool> get isPermissionBluetoothGranted async =>
      permissionBluetoothGranted;

  @override
  Future<bool> get disconnect async {
    disconnectCount++;
    _connected = false;
    return true;
  }

  @override
  Future<List<BluetoothInfo>> get pairedBluetooths async => _pairedPrinters;

  @override
  Future<bool> connect({required String macPrinterAddress}) async {
    connectCount++;
    _connected = connectResult;
    return connectResult;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestedPermissions.addAll(permissions);
    return {
      for (final permission in permissions)
        if (_permissionStatuses.containsKey(permission))
          permission: _permissionStatuses[permission]!,
    };
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    writeCount++;
    lastWrite = List<int>.of(bytes);
    final result = _writeResults.isEmpty ? true : _writeResults.removeAt(0);
    if (result is Exception) throw result;
    return result as bool;
  }
}

ReceiptDocument _receiptWithProduct(
  String productName, {
  String paymentMethod = 'Tunai',
  StoreSettings settings = const StoreSettings(businessName: 'BuildEra'),
  String? customerName,
  Map<String, dynamic> extraMetadata = const {},
}) {
  final now = DateTime(2026, 1, 1);
  return ReceiptDocument(
    title: 'Test',
    lines: const [],
    metadata: {
      'settings': settings,
      ...extraMetadata,
      'transaction': Transaction(
        id: 'tx-1',
        invoiceNumber: 'INV-1',
        customerName: customerName,
        cashierName: 'Kasir Uji',
        subtotal: 1000,
        itemDiscountTotal: 0,
        transDiscountValue: 0,
        transDiscountType: DiscountType.fixed,
        transDiscountAmount: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 1000,
        paymentMethod: paymentMethod,
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

List<String> _receiptTextLines(List<int> bytes) {
  final output = <int>[];
  var index = 0;
  while (index < bytes.length) {
    if (bytes[index] == 0x1B) {
      index += index + 1 < bytes.length && bytes[index + 1] == 0x40 ? 2 : 3;
      continue;
    }
    if (bytes[index] == 0x1D) {
      if (index + 3 < bytes.length &&
          bytes[index + 1] == 0x76 &&
          bytes[index + 2] == 0x30) {
        final widthBytes = bytes[index + 4] + (bytes[index + 5] << 8);
        final height = bytes[index + 6] + (bytes[index + 7] << 8);
        index += 8 + widthBytes * height;
      } else {
        index += 3;
      }
      continue;
    }
    if (bytes[index] == 0x0A) {
      output.add(0x0A);
    } else if (bytes[index] >= 0x20 && bytes[index] < 0x7F) {
      output.add(bytes[index]);
    }
    index++;
  }
  return String.fromCharCodes(output)
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList();
}

ReceiptDocument _debtReceipt({
  required DateTime createdAt,
  Uint8List? qrisBytes,
  List<DebtPayment> paymentHistory = const [],
}) {
  final transaction = _receiptWithProduct(
    'Pipa',
    paymentMethod: AppConstants.paymentPiutang,
  ).metadata['transaction'] as Transaction;
  final customer = Customer(
    id: 'customer-1',
    name: 'Pelanggan Uji',
    phone: '081234567',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
  final debt = Debt(
    id: 'debt-1',
    transactionId: transaction.id,
    customerId: customer.id,
    customerName: customer.name,
    invoiceNumber: 'INV-PIUTANG',
    totalAmount: 1000,
    paidAmount: 250,
    remainingBalance: 750,
    dueDate: DateTime(2024, 3, 3),
    createdAt: createdAt,
    updatedAt: createdAt,
    status: DebtStatus.partiallyPaid,
  );
  final metadata = <String, dynamic>{
    'settings': const StoreSettings(
      businessName: 'BuildEra',
      bankAccounts: [
        BankAccount(
          bankName: 'Bank Contoh',
          accountNumber: '123456',
          accountHolder: 'Toko BuildEra',
        ),
      ],
    ),
    'transaction': transaction,
    'customer': customer,
    'debt': debt,
    'payments': paymentHistory,
  };
  if (qrisBytes != null) metadata['qrisBytes'] = qrisBytes;
  return ReceiptDocument(
      title: 'STRUK TAGIHAN', lines: const [], metadata: metadata);
}

int _indexOfBytes(List<int> bytes, List<int> sequence) {
  for (var index = 0; index <= bytes.length - sequence.length; index++) {
    var matches = true;
    for (var offset = 0; offset < sequence.length; offset++) {
      if (bytes[index + offset] != sequence[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return index;
    }
  }
  return -1;
}

bool _containsBytes(List<int> bytes, List<int> sequence) =>
    _indexOfBytes(bytes, sequence) >= 0;
