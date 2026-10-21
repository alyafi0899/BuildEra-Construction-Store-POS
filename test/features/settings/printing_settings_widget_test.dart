import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:buildera/features/settings/presentation/widgets/printing_settings_widget.dart';
import 'package:buildera/printing/services/bluetooth_printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows pairing guidance when no paired printers are found',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = _service(pairedPrinters: []);
    await _openPicker(tester, service);

    expect(find.textContaining('1. Nyalakan printer.'), findsOneWidget);
    expect(find.text('Buka Pengaturan Bluetooth'), findsOneWidget);
    expect(find.text('Muat Ulang'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opens Android Bluetooth settings with the expected action',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = _service(pairedPrinters: []);
    AndroidIntent? launchedIntent;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showBluetoothPrinterPickerDialog(
                  context,
                  service: service,
                  launchIntent: (intent) async {
                    launchedIntent = intent;
                  },
                );
              },
              child: const Text('Tampilkan pemilih'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tampilkan pemilih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka Pengaturan Bluetooth'));
    await tester.pumpAndSettle();

    expect(launchedIntent?.action, 'android.settings.BLUETOOTH_SETTINGS');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reloads paired printers when the app resumes', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final printers = <BluetoothInfo>[];
    final transport = _PickerTransport(printers);
    final service = BluetoothPrinterService(
      transport: transport,
      permissionCheck: () async {},
    );
    await _openPicker(tester, service);
    expect(find.text('Printer Label'), findsNothing);

    printers.add(BluetoothInfo(name: 'Printer Label', macAdress: 'AA:BB'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Printer Label'), findsOneWidget);
    expect(transport.pairedReadCount, greaterThanOrEqualTo(2));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('warns when Bluetooth is selected without a printer',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _openPrintingSettings(
      tester,
      printerTransport: 'bluetooth',
      printMethod: 'pdf',
    );

    expect(
        find.text('Pilih printer Bluetooth terlebih dahulu'), findsOneWidget);
    expect(
      find.textContaining('Bluetooth thermal mencetak langsung di Android'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('warns when Android RAW is paired with unsupported transport',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _openPrintingSettings(
      tester,
      printerTransport: 'usb',
      printMethod: 'raw',
    );

    expect(
      find.text(
        'Peringatan: Mode RAW di Android hanya didukung untuk Bluetooth atau '
        'TCP dengan desain Fast Raw.',
      ),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _openPrintingSettings(
  WidgetTester tester, {
  required String printerTransport,
  required String printMethod,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrintingSettingsWidget(
            widthCtrl: TextEditingController(text: '80'),
            marginCtrl: TextEditingController(text: '4'),
            useFastPrint: true,
            autoCut: true,
            printerTransport: printerTransport,
            invoiceDesign: 'classic',
            printMethod: printMethod,
            onFastPrintChanged: (_) {},
            onAutoCutChanged: (_) {},
            onTransportChanged: (_) {},
            onDesignChanged: (_) {},
            onMethodChanged: (_) {},
            onInvoicePrinterChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BluetoothPrinterService _service({
  required List<BluetoothInfo> pairedPrinters,
}) =>
    BluetoothPrinterService(
      transport: _PickerTransport(pairedPrinters),
      permissionCheck: () async {},
    );

Future<void> _openPicker(
  WidgetTester tester,
  BluetoothPrinterService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showBluetoothPrinterPickerDialog(context, service: service),
            child: const Text('Tampilkan pemilih'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Tampilkan pemilih'));
  await tester.pumpAndSettle();
}

class _PickerTransport implements BluetoothPrinterTransport {
  _PickerTransport(this.printers);

  final List<BluetoothInfo> printers;
  int pairedReadCount = 0;

  @override
  Future<bool> get connectionStatus async => false;

  @override
  Future<bool> get bluetoothEnabled async => true;

  @override
  Future<bool> get isPermissionBluetoothGranted async => true;

  @override
  Future<bool> get disconnect async => true;

  @override
  Future<List<BluetoothInfo>> get pairedBluetooths async {
    pairedReadCount++;
    return List.of(printers);
  }

  @override
  Future<bool> connect({required String macPrinterAddress}) async => true;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async =>
      {
        for (final permission in permissions)
          permission: PermissionStatus.granted,
      };

  @override
  Future<bool> writeBytes(List<int> bytes) async => true;
}
