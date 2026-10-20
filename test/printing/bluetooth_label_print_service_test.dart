import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:buildera/printing/models/label_template.dart';
import 'package:buildera/printing/models/print_document.dart';
import 'package:buildera/printing/services/bluetooth_label_print_service.dart';
import 'package:buildera/printing/services/bluetooth_printer_service.dart';

void main() {
  test('sends ZPL barcode bytes over Bluetooth without using PDF output',
      () async {
    final transport = _LabelTransport();
    final service = BluetoothLabelPrintService(
      bluetoothPrinterService: BluetoothPrinterService(
        transport: transport,
        permissionCheck: () async {},
      ),
    );
    var pdfPrintCount = 0;

    await service.printLabels(
      label: _label([_item('111222333444')]),
      settings: const LabelTemplateSettings(),
      language: 'zpl',
      isAndroid: true,
      printerAddress: 'printer-1',
      printPdf: () async {
        pdfPrintCount++;
      },
    );

    expect(pdfPrintCount, 0);
    expect(transport.writes, hasLength(1));
    expect(utf8.decode(transport.writes.single), contains('^BC'));
    expect(utf8.decode(transport.writes.single), contains('111222333444'));
  });

  test('reports when no Bluetooth label printer is configured', () async {
    final service = BluetoothLabelPrintService(
      bluetoothPrinterService: BluetoothPrinterService(
        transport: _LabelTransport(),
        permissionCheck: () async {},
      ),
    );
    var pdfPrintCount = 0;

    await expectLater(
      service.printLabels(
        label: _label([_item('111222333444')]),
        settings: const LabelTemplateSettings(),
        language: 'zpl',
        isAndroid: true,
        printerAddress: null,
        printPdf: () async {
          pdfPrintCount++;
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Printer label Bluetooth belum dikonfigurasi'),
        ),
      ),
    );
    expect(pdfPrintCount, 0);
  });

  test('routes TSPL label language through the Bluetooth raw transport',
      () async {
    final transport = _LabelTransport();
    final service = BluetoothLabelPrintService(
      bluetoothPrinterService: BluetoothPrinterService(
        transport: transport,
        permissionCheck: () async {},
      ),
    );

    await service.printLabels(
      label: _label([_item('111222333444')]),
      settings: const LabelTemplateSettings(),
      language: 'tspl',
      isAndroid: true,
      printerAddress: 'printer-1',
      printPdf: () async {},
    );

    final payload = utf8.decode(transport.writes.single);
    expect(payload, contains('SIZE 40.0 mm,30.0 mm'));
    expect(payload, contains('BARCODE'));
  });

  test('waits for each label write before sending the next label', () async {
    final transport =
        _LabelTransport(writeDelay: const Duration(milliseconds: 2));
    final service = BluetoothLabelPrintService(
      bluetoothPrinterService: BluetoothPrinterService(
        transport: transport,
        permissionCheck: () async {},
      ),
    );

    await service.printLabels(
      label: _label([
        _item('111222333444'),
        _item('555666777888'),
      ]),
      settings: const LabelTemplateSettings(),
      language: 'zpl',
      isAndroid: true,
      printerAddress: 'printer-1',
      printPdf: () async {},
    );

    expect(transport.writes, hasLength(2));
    expect(transport.maximumConcurrentWrites, 1);
    expect(utf8.decode(transport.writes[0]), contains('111222333444'));
    expect(utf8.decode(transport.writes[1]), contains('555666777888'));
  });

  test('retries a failed raw Bluetooth write once', () async {
    final transport = _LabelTransport(writeResults: [false, true]);
    final bluetoothPrinter = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );

    await bluetoothPrinter.printRaw('printer-1', [0x5A, 0x50, 0x4C]);

    expect(transport.writes, hasLength(2));
  });

  test('keeps non-Android label printing on the existing PDF path', () async {
    final transport = _LabelTransport();
    final service = BluetoothLabelPrintService(
      bluetoothPrinterService: BluetoothPrinterService(
        transport: transport,
        permissionCheck: () async {},
      ),
    );
    var pdfPrintCount = 0;

    await service.printLabels(
      label: _label([_item('111222333444')]),
      settings: const LabelTemplateSettings(),
      language: 'zpl',
      isAndroid: false,
      printerAddress: 'printer-1',
      printPdf: () async {
        pdfPrintCount++;
      },
    );

    expect(pdfPrintCount, 1);
    expect(transport.writes, isEmpty);
  });
}

LabelDocument _label(List<Map<String, dynamic>> items) => LabelDocument(
      title: 'LABEL',
      lines: const [],
      metadata: {'items': items},
    );

Map<String, dynamic> _item(String barcode) => {
      'businessName': 'BuildEra',
      'productName': 'Uji Label',
      'barcode': barcode,
      'price': 'Rp. 10.000',
    };

class _LabelTransport implements BluetoothPrinterTransport {
  _LabelTransport({
    this.writeDelay = Duration.zero,
    List<bool>? writeResults,
  }) : _writeResults = List.of(writeResults ?? [true]);

  final Duration writeDelay;
  final List<bool> _writeResults;
  final List<List<int>> writes = [];
  bool _connected = false;
  int _activeWrites = 0;
  int maximumConcurrentWrites = 0;

  @override
  Future<bool> get connectionStatus async => _connected;

  @override
  Future<bool> get bluetoothEnabled async => true;

  @override
  Future<bool> get isPermissionBluetoothGranted async => true;

  @override
  Future<bool> get disconnect async {
    _connected = false;
    return true;
  }

  @override
  Future<List<BluetoothInfo>> get pairedBluetooths async => [
        BluetoothInfo(name: 'Label', macAdress: 'printer-1'),
      ];

  @override
  Future<bool> connect({required String macPrinterAddress}) async {
    _connected = true;
    return true;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async =>
      {
        for (final permission in permissions)
          permission: PermissionStatus.granted,
      };

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    _activeWrites++;
    if (_activeWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = _activeWrites;
    }
    await Future<void>.delayed(writeDelay);
    writes.add(List.of(bytes));
    _activeWrites--;
    return _writeResults.isEmpty ? true : _writeResults.removeAt(0);
  }
}
