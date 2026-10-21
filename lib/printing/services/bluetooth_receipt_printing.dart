import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/utils/image_helper.dart';
import '../../features/debts/models/customer.dart';
import '../../features/debts/models/debt.dart';
import '../../features/debts/models/debt_payment.dart';
import '../../features/settings/models/store_settings.dart';
import '../../shared/models/purchase.dart';
import '../../shared/models/transaction.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';
import 'bluetooth_printer_service.dart';

Future<void> printBluetoothReceipt({
  required String address,
  required StoreSettings settings,
  Transaction? transaction,
  Purchase? purchase,
  Customer? customer,
  Debt? debt,
  List<DebtPayment>? payments,
}) async {
  if (address.isEmpty) {
    throw StateError(
      'Pilih dan hubungkan printer Bluetooth di Pengaturan Printer '
      'sebelum mencetak.',
    );
  }

  if (!Platform.isAndroid) {
    throw StateError('Cetak Bluetooth langsung hanya tersedia di Android.');
  }

  final title = purchase != null
      ? 'PEMBELIAN'
      : debt != null
          ? 'NOTA PIUTANG'
          : settings.businessName.toUpperCase();
  final metadata = <String, dynamic>{'settings': settings};
  final logoBytes = await _readImageBytes(settings.logoUrl);
  final qrisBytes = await _readImageBytes(settings.qrisImagePath);
  if (kDebugMode) {
    debugPrint(
      'Bluetooth receipt images: '
      'logo bytes=${logoBytes?.length ?? 0}, '
      'QRIS bytes=${qrisBytes?.length ?? 0}',
    );
  }
  if (logoBytes != null) metadata['logoBytes'] = logoBytes;
  if (qrisBytes != null) metadata['qrisBytes'] = qrisBytes;
  if (transaction != null) metadata['transaction'] = transaction;
  if (purchase != null) metadata['purchase'] = purchase;
  if (customer != null) metadata['customer'] = customer;
  if (debt != null) metadata['debt'] = debt;
  if (payments != null) metadata['payments'] = payments;

  final profile = PrinterProfile(
    id: 'receipt-bluetooth',
    name: 'Bluetooth Receipt',
    transport: PrinterTransport.escposBluetooth,
    address: address,
    paperWidthMm: settings.receiptWidth,
    marginMm: settings.receiptMargin,
    defaults: {'autoCut': settings.autoCut},
  );

  await BluetoothPrinterService().printReceipt(
    address: address,
    receipt: ReceiptDocument(title: title, lines: const [], metadata: metadata),
    profile: profile,
  );
}

Future<Uint8List?> _readImageBytes(String? storedPath) async {
  if (storedPath == null || storedPath.isEmpty) return null;
  try {
    final localPath = await ImageHelper.resolveLocalPath(storedPath);
    if (localPath == null) return null;
    return await File(localPath).readAsBytes();
  } catch (error) {
    debugPrint('Tidak dapat memuat gambar struk; gambar dilewati: $error');
    return null;
  }
}
