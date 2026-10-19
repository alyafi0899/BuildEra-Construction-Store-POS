import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../drivers/escpos/escpos_driver.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';

abstract interface class BluetoothPrinterTransport {
  Future<bool> get connectionStatus;
  Future<bool> get bluetoothEnabled;
  Future<bool> get disconnect;
  Future<bool> connect({required String macPrinterAddress});
  Future<bool> writeBytes(List<int> bytes);
}

class _PluginBluetoothPrinterTransport implements BluetoothPrinterTransport {
  @override
  Future<bool> get connectionStatus => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<bool> get disconnect async => PrintBluetoothThermal.disconnect;

  @override
  Future<bool> connect({required String macPrinterAddress}) =>
      PrintBluetoothThermal.connect(macPrinterAddress: macPrinterAddress);

  @override
  Future<bool> writeBytes(List<int> bytes) =>
      PrintBluetoothThermal.writeBytes(bytes);
}

class BluetoothPrinterService {
  static final BluetoothPrinterService _shared = BluetoothPrinterService._(
    transport: _PluginBluetoothPrinterTransport(),
  );

  factory BluetoothPrinterService({
    BluetoothPrinterTransport? transport,
    Future<void> Function()? permissionCheck,
  }) {
    if (transport == null && permissionCheck == null) return _shared;
    return BluetoothPrinterService._(
      transport: transport ?? _PluginBluetoothPrinterTransport(),
      permissionCheck: permissionCheck,
    );
  }

  BluetoothPrinterService._({
    required BluetoothPrinterTransport transport,
    Future<void> Function()? permissionCheck,
  })  : _transport = transport,
        _permissionCheck = permissionCheck;

  final BluetoothPrinterTransport _transport;
  final Future<void> Function()? _permissionCheck;
  String? _connectedAddress;

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    await _ensureBluetoothPermission();
    await _ensureBluetoothEnabled();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> connectPrinter(String address) async {
    await _ensureBluetoothPermission();
    await _ensureBluetoothEnabled();

    bool connected;
    try {
      await _transport.disconnect;
      connected = await _transport.connect(macPrinterAddress: address);
    } catch (_) {
      _connectedAddress = null;
      throw StateError(_connectionError);
    }
    if (!connected) {
      _connectedAddress = null;
      throw StateError(_connectionError);
    }
    _connectedAddress = address;
  }

  Future<void> printReceipt({
    required String address,
    required ReceiptDocument receipt,
    required PrinterProfile profile,
  }) async {
    final result = EscPosDriver().printReceipt(receipt, profile);
    if (!result.success || result.bytes == null || result.bytes!.isEmpty) {
      throw StateError(result.message);
    }

    if (_connectedAddress != address || !await _transport.connectionStatus) {
      await connectPrinter(address);
    }

    if (await _tryWrite(result.bytes!)) return;

    _connectedAddress = null;
    var retrySucceeded = false;
    try {
      await connectPrinter(address);
      retrySucceeded = await _tryWrite(result.bytes!);
    } catch (_) {
      _connectedAddress = null;
    }
    if (retrySucceeded) return;
    _connectedAddress = null;

    throw StateError(_writeError);
  }

  Future<bool> _tryWrite(List<int> bytes) async {
    try {
      return await _transport.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureBluetoothEnabled() async {
    if (!await _transport.bluetoothEnabled) {
      throw StateError(
        'Bluetooth ponsel sedang mati. Aktifkan Bluetooth lalu coba lagi.',
      );
    }
  }

  Future<void> _ensureBluetoothPermission() async {
    final permissionCheck = _permissionCheck;
    if (permissionCheck != null) {
      await permissionCheck();
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) return;

    final status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) {
      throw StateError(
        status.isPermanentlyDenied
            ? 'Izin Bluetooth ditolak permanen. Aktifkan izin Perangkat '
                'Terdekat untuk BuildEra di Pengaturan aplikasi.'
            : 'Izin Perangkat Terdekat diperlukan untuk memilih dan '
                'menghubungkan printer Bluetooth.',
      );
    }
  }

  static const _connectionError =
      'Gagal terhubung ke printer. Pastikan printer menyala, sudah '
      'dipasangkan di pengaturan Bluetooth ponsel, dan tidak sedang '
      'terhubung ke perangkat lain.';

  static const _writeError =
      'Printer terhubung, tetapi data struk tidak terkirim. '
      'Periksa printer dan coba lagi.';
}
