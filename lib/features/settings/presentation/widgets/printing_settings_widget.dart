import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../printing/services/bluetooth_printer_service.dart';

class PrintingSettingsWidget extends StatelessWidget {
  final TextEditingController widthCtrl;
  final TextEditingController marginCtrl;
  final bool useFastPrint;
  final bool autoCut;
  final String printerTransport;
  final String invoiceDesign;
  final String printMethod;
  final String? invoicePrinterUrl;
  final ValueChanged<bool> onFastPrintChanged;
  final ValueChanged<bool> onAutoCutChanged;
  final ValueChanged<String> onTransportChanged;
  final ValueChanged<String> onDesignChanged;
  final ValueChanged<String> onMethodChanged;
  final ValueChanged<String?> onInvoicePrinterChanged;

  const PrintingSettingsWidget({
    super.key,
    required this.widthCtrl,
    required this.marginCtrl,
    required this.useFastPrint,
    required this.autoCut,
    required this.printerTransport,
    required this.invoiceDesign,
    required this.printMethod,
    this.invoicePrinterUrl,
    required this.onFastPrintChanged,
    required this.onAutoCutChanged,
    required this.onTransportChanged,
    required this.onDesignChanged,
    required this.onMethodChanged,
    required this.onInvoicePrinterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.print_rounded, size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Format Struk',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lebar Kertas (mm)',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: widthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.straighten_rounded, size: 20),
                          hintText: 'Contoh: 80, 58',
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Margin Kiri (pt)',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: marginCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.padding_rounded, size: 20),
                          hintText: 'Misal: 4, 8, 12',
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Tips: Naikkan "Margin Kiri" jika teks terpotong di kiri. Umumnya 4-12pt tergantung printer. 1mm = 2.8pt.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
            const Row(
              children: [
                Icon(Icons.style_rounded, size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Desain Struk',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: invoiceDesign,
              decoration: InputDecoration(
                labelText: 'Pilih Style Desain',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabled:
                    printMethod != 'raw', // Disable if Direct Raw is selected
              ),
              items: const [
                DropdownMenuItem(
                    value: 'classic', child: Text('Classic (PDF)')),
                DropdownMenuItem(
                    value: 'modern', child: Text('Modern (PDF - Clean)')),
                DropdownMenuItem(
                    value: 'fast',
                    child: Text('Fast Raw (Native Font - Sangat Cepat)')),
              ],
              onChanged: (v) => onDesignChanged(v!),
            ),
            const SizedBox(height: 8),
            Text(
              printMethod == 'raw'
                  ? 'Info: Mode Direct Raw diatur khusus untuk desain "Fast Raw" guna menjamin kecepatan dan kejelasan.'
                  : switch (invoiceDesign) {
                      'fast' =>
                        'Fast Raw memakai jalur ESC/POS native jika transport mendukungnya.',
                      'modern' =>
                        'Modern mencetak PDF dengan tata letak bersih; driver perlu mendukung grafik.',
                      _ =>
                        'Classic mencetak PDF dengan tata letak standar melalui printer sistem.',
                    },
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.settings_ethernet_rounded,
                    size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Metode Pengiriman Data',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: printMethod,
              decoration: const InputDecoration(
                labelText: 'Pilih Jalur Data',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'pdf', child: Text('Standard PDF (High Fidelity)')),
                DropdownMenuItem(
                    value: 'raw',
                    child: Text('Direct Raw Spooler (High Speed - No PDF)')),
              ],
              onChanged: (v) {
                onMethodChanged(v!);
                if (v == 'raw') {
                  onDesignChanged('fast');
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              printMethod == 'raw'
                  ? 'Direct Raw melewati PDF. Jalur yang tersedia bergantung pada platform dan tipe koneksi.'
                  : 'Standard PDF merender struk sebagai dokumen dan memakai printer/driver sistem.',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
            if (defaultTargetPlatform == TargetPlatform.android &&
                printMethod == 'raw' &&
                printerTransport != 'bluetooth' &&
                !(printerTransport == 'tcp' && invoiceDesign == 'fast')) ...[
              const SizedBox(height: 8),
              const Text(
                'Peringatan: Mode RAW di Android hanya didukung untuk '
                'Bluetooth atau TCP dengan desain Fast Raw.',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ],
            const Divider(height: 40),
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Optimalisasi Kecepatan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile.adaptive(
                      value: useFastPrint,
                      onChanged: onFastPrintChanged,
                      title: const Text('Mode Cetak Cepat (Native)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text(
                          'Gunakan font bawaan printer untuk cetak lebih cepat. Lewati dialog sistem.',
                          style: TextStyle(fontSize: 12)),
                      activeTrackColor: AppTheme.accent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile.adaptive(
                      value: autoCut,
                      onChanged: onAutoCutChanged,
                      title: const Text('Potong Kertas Otomatis',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text(
                          'Matikan jika printer tidak memiliki pemotong otomatis.',
                          style: TextStyle(fontSize: 12)),
                      activeTrackColor: AppTheme.accent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (useFastPrint) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Tipe Koneksi Printer',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: printerTransport,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'usb',
                                  child: Text('USB',
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: 'bluetooth',
                                  child: Text('Bluetooth',
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: 'tcp',
                                  child: Text('Network / Wi-Fi',
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: 'pdf',
                                  child: Text('System (Slow)',
                                      style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => onTransportChanged(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (printerTransport) {
                        'usb' =>
                          'USB raw tersedia melalui spooler Windows; USB ESC/POS Android belum didukung.',
                        'bluetooth' =>
                          'Bluetooth thermal mencetak langsung di Android; di Windows gunakan spooler printer.',
                        'tcp' =>
                          'Network/Wi-Fi memakai TCP raw untuk invoice/piutang dengan desain Fast Raw.',
                        _ =>
                          'System mencetak PDF melalui dialog atau layanan cetak perangkat.',
                      },
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Printer Struk Utama',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                        SizedBox(
                          width: 180,
                          child: OutlinedButton(
                            onPressed: () async {
                              if (defaultTargetPlatform ==
                                      TargetPlatform.android &&
                                  printerTransport == 'bluetooth') {
                                await _selectBluetoothPrinter(context);
                                return;
                              }

                              final printer =
                                  await Printing.pickPrinter(context: context);
                              if (printer != null) {
                                onInvoicePrinterChanged(printer.url);
                              }
                            },
                            child: Text(
                              printerTransport == 'bluetooth' &&
                                      defaultTargetPlatform ==
                                          TargetPlatform.android
                                  ? invoicePrinterUrl ??
                                      'Pilih Printer Bluetooth...'
                                  : invoicePrinterUrl ?? 'Pilih Printer...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (printerTransport == 'bluetooth' &&
                            (invoicePrinterUrl?.trim().isEmpty ?? true)) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Pilih printer Bluetooth terlebih dahulu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (printerTransport == 'bluetooth' &&
                        defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Satu printer hanya bisa dipakai satu aplikasi pada '
                        'satu waktu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBluetoothPrinter(BuildContext context) async {
    try {
      final printer = await showBluetoothPrinterPickerDialog(context);
      if (printer == null || !context.mounted) return;

      await BluetoothPrinterService().connectPrinter(printer.macAdress);
      if (!context.mounted) return;

      onInvoicePrinterChanged(printer.macAdress);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terhubung ke ${printer.name}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Gagal menghubungkan printer: $e');
      }
    }
  }
}

Future<BluetoothInfo?> showBluetoothPrinterPickerDialog(
  BuildContext context, {
  BluetoothPrinterService? service,
  Future<void> Function(AndroidIntent intent)? launchIntent,
}) {
  return showDialog<BluetoothInfo>(
    context: context,
    builder: (context) => BluetoothPrinterPickerDialog(
      service: service ?? BluetoothPrinterService(),
      launchIntent: launchIntent ?? (intent) => intent.launch(),
    ),
  );
}

class BluetoothPrinterPickerDialog extends StatefulWidget {
  const BluetoothPrinterPickerDialog({
    required this.service,
    required this.launchIntent,
    super.key,
  });

  final BluetoothPrinterService service;
  final Future<void> Function(AndroidIntent intent) launchIntent;

  @override
  State<BluetoothPrinterPickerDialog> createState() =>
      _BluetoothPrinterPickerDialogState();
}

class _BluetoothPrinterPickerDialogState
    extends State<BluetoothPrinterPickerDialog> with WidgetsBindingObserver {
  List<BluetoothInfo> _printers = [];
  String? _loadError;
  String? _settingsError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloadPrinters();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadPrinters();
    }
  }

  Future<void> _reloadPrinters() async {
    if (_isLoading || !mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final printers = await widget.service.getPairedPrinters();
      if (mounted) setState(() => _printers = printers);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBluetoothSettings() async {
    setState(() => _settingsError = null);
    try {
      await widget.launchIntent(
        const AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS'),
      );
    } catch (error) {
      if (mounted) {
        setState(() =>
            _settingsError = 'Gagal membuka Pengaturan Bluetooth: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return AlertDialog(
      title: const Text('Pilih Printer Bluetooth'),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Nyalakan printer.\n'
                '2. Buka Pengaturan Bluetooth Android lalu pasangkan printer '
                '(PIN biasanya 0000 atau 1234).\n'
                '3. Kembali ke BuildEra lalu ketuk Muat Ulang.',
              ),
              if (_loadError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat daftar printer: $_loadError',
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ],
              if (_settingsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _settingsError!,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ] else if (_printers.isNotEmpty) ...[
                const Divider(height: 24),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _printers
                        .map(
                          (device) => ListTile(
                            leading: const Icon(Icons.print_rounded),
                            title: Text(
                              device.name.isEmpty
                                  ? 'Printer Bluetooth'
                                  : device.name,
                            ),
                            subtitle: Text(device.macAdress),
                            onTap: () => Navigator.of(context)
                                .pop<BluetoothInfo>(device),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isAndroid)
                    OutlinedButton(
                      onPressed: _openBluetoothSettings,
                      child: const Text('Buka Pengaturan Bluetooth'),
                    ),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _reloadPrinters,
                    child: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
