import '../models/label_template.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';
import 'bluetooth_printer_service.dart';
import 'print_orchestrator.dart';

class BluetoothLabelPrintService {
  BluetoothLabelPrintService({
    BluetoothPrinterService? bluetoothPrinterService,
    PrintOrchestrator? printOrchestrator,
  })  : _bluetoothPrinterService =
            bluetoothPrinterService ?? BluetoothPrinterService(),
        _printOrchestrator = printOrchestrator ?? PrintOrchestrator();

  final BluetoothPrinterService _bluetoothPrinterService;
  final PrintOrchestrator _printOrchestrator;

  Future<void> printLabels({
    required LabelDocument label,
    required LabelTemplateSettings settings,
    required String language,
    required bool isAndroid,
    required String? printerAddress,
    required Future<void> Function() printPdf,
  }) async {
    if (!isAndroid || language == 'pdf') {
      await printPdf();
      return;
    }

    if (printerAddress == null || printerAddress.isEmpty) {
      throw StateError(
        'Printer label Bluetooth belum dikonfigurasi. Pilih printer label '
        'Bluetooth terlebih dahulu.',
      );
    }

    final transport = switch (language) {
      'zpl' => PrinterTransport.zpl,
      'tspl' => PrinterTransport.tspl,
      _ => throw StateError('Bahasa printer label tidak dikenal: $language'),
    };
    final labelJobs = _labelJobs(label);

    for (var index = 0; index < labelJobs.length; index++) {
      final jobMetadata = Map<String, dynamic>.of(label.metadata);
      if (labelJobs[index] != null) {
        jobMetadata['items'] = [labelJobs[index]];
      }
      final job = LabelDocument(
        title: label.title,
        lines: label.lines,
        barcode: label.barcode,
        metadata: jobMetadata,
      );
      final result = await _printOrchestrator.printLabel(
        job,
        PrinterProfile(
          id: 'bluetooth-label',
          name: 'Bluetooth Label',
          transport: transport,
          address: printerAddress,
        ),
        settings: settings,
      );
      if (!result.success || result.bytes == null || result.bytes!.isEmpty) {
        throw StateError(
          'Gagal membuat data label ${index + 1}: ${result.message}',
        );
      }

      try {
        await _bluetoothPrinterService.printRaw(printerAddress, result.bytes!);
      } catch (error) {
        throw StateError(
          'Gagal mencetak label ${index + 1} dari ${labelJobs.length}: $error',
        );
      }
    }
  }

  List<Map<String, dynamic>?> _labelJobs(LabelDocument label) {
    final items = label.metadata['items'];
    if (items == null) return [null];
    if (items is! List) {
      throw StateError('Data item label tidak valid.');
    }
    if (items.isEmpty) return [null];

    return items.map((item) {
      if (item is! Map) {
        throw StateError('Data item label tidak valid.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }
}
