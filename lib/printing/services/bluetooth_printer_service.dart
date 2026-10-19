import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../drivers/escpos/escpos_driver.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';

class BluetoothPrinterService {
  Future<List<BluetoothInfo>> getPairedPrinters() async {
    await _ensureBluetoothPermission();
    await _ensureBluetoothEnabled();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> connectPrinter(String address) async {
    await _ensureBluetoothPermission();
    await _ensureBluetoothEnabled();

    await PrintBluetoothThermal.disconnect;
    final connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: address);
    if (!connected) {
      throw StateError(
        'Gagal terhubung ke printer. Pastikan printer menyala, sudah '
        'dipasangkan di pengaturan Bluetooth ponsel, dan tidak sedang '
        'terhubung ke perangkat lain.',
      );
    }
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

    await connectPrinter(address);
    final printed = await PrintBluetoothThermal.writeBytes(result.bytes!);
    if (!printed) {
      throw StateError(
        'Printer terhubung, tetapi data struk tidak terkirim. '
        'Periksa printer dan coba lagi.',
      );
    }
  }

  Future<void> _ensureBluetoothEnabled() async {
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw StateError(
        'Bluetooth ponsel sedang mati. Aktifkan Bluetooth lalu coba lagi.',
      );
    }
  }

  Future<void> _ensureBluetoothPermission() async {
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
}
