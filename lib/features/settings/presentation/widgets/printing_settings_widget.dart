import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';

class PrintingSettingsWidget extends StatelessWidget {
  final TextEditingController widthCtrl;
  final TextEditingController marginCtrl;
  final bool useFastPrint;
  final String printerTransport;
  final String invoiceDesign;
  final String? invoicePrinterUrl;
  final ValueChanged<bool> onFastPrintChanged;
  final ValueChanged<String> onTransportChanged;
  final ValueChanged<String> onDesignChanged;
  final ValueChanged<String?> onInvoicePrinterChanged;

  const PrintingSettingsWidget({
    super.key,
    required this.widthCtrl,
    required this.marginCtrl,
    required this.useFastPrint,
    required this.printerTransport,
    required this.invoiceDesign,
    this.invoicePrinterUrl,
    required this.onFastPrintChanged,
    required this.onTransportChanged,
    required this.onDesignChanged,
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
                Text('Format Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lebar Kertas (mm)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: widthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
                      const Text('Margin Kiri (pt)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: marginCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            ),
            const Row(
              children: [
                Icon(Icons.style_rounded, size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Desain Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: invoiceDesign,
              decoration: const InputDecoration(
                labelText: 'Pilih Style Desain',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'classic', child: Text('Classic (PDF)')),
                DropdownMenuItem(value: 'modern', child: Text('Modern (PDF - Clean)')),
                DropdownMenuItem(value: 'fast', child: Text('Fast Raw (Native Font - Sangat Cepat)')),
              ],
              onChanged: (v) => onDesignChanged(v!),
            ),
            const SizedBox(height: 8),
            Text(
              invoiceDesign == 'fast' 
                ? 'Tips: Mode Fast menggunakan font bawaan printer (thin font). Sangat cepat namun layout terbatas.'
                : 'Tips: Mode Classic/Modern menggunakan PDF. Lebih rapi namun sedikit lebih lambat di beberapa printer thermal.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            ),
            const Divider(height: 40),
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 20, color: AppTheme.accent),
                SizedBox(width: 12),
                Text('Optimalisasi Kecepatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  SwitchListTile.adaptive(
                    value: useFastPrint,
                    onChanged: onFastPrintChanged,
                    title: const Text('Mode Cetak Cepat (Native)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Gunakan font bawaan printer untuk cetak lebih cepat. Lewati dialog sistem.', style: TextStyle(fontSize: 12)),
                    activeColor: AppTheme.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (useFastPrint) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Tipe Koneksi Printer', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: printerTransport,
                            isDense: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'usb', child: Text('USB', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'tcp', child: Text('Network / Wi-Fi', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'pdf', child: Text('System (Slow)', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => onTransportChanged(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Printer Struk Utama', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                        SizedBox(
                          width: 180,
                          child: OutlinedButton(
                            onPressed: () async {
                              final printer = await Printing.pickPrinter(context: context);
                              if (printer != null) {
                                onInvoicePrinterChanged(printer.url);
                              }
                            },
                            child: Text(
                              invoicePrinterUrl ?? 'Pilih Printer...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
