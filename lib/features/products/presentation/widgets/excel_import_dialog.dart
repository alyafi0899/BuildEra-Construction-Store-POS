import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';

class ExcelImportDialog extends ConsumerStatefulWidget {
  const ExcelImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ExcelImportDialog(),
    );
  }

  @override
  ConsumerState<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends ConsumerState<ExcelImportDialog> {
  bool _importing = false;
  String? _status;
  final _uuid = const Uuid();

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _importing = true;
      _status = 'Membaca file...';
    });

    try {
      final bytes = result.files.first.bytes!;
      final excel = Excel.decodeBytes(bytes);
      final productsToImport = <Map<Product, List<ProductUnit>>>[];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        // Skip header row
        for (var i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final name = row[0]?.value?.toString() ?? '';
          if (name.isEmpty) continue;

          final category = row[1]?.value?.toString() ?? 'Lainnya';
          final barcode = row[2]?.value?.toString();
          final basePrice = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
          final baseUnit = row[4]?.value?.toString() ?? 'pcs';
          final stock = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
          
          final productId = _uuid.v4();
          final product = Product(
            id: productId,
            name: name,
            category: category,
            barcode: barcode,
            costPrice: 0, // Default to 0 on import if not in excel
            basePrice: basePrice,
            baseUnit: baseUnit,
            stock: stock,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final units = <ProductUnit>[];
          // Add default unit based on base price
          units.add(ProductUnit(
            id: _uuid.v4(),
            productId: productId,
            unitName: baseUnit,
            conversionRate: 1,
            sellPrice: basePrice,
          ));

          // Handle additional units from column G (index 6)
          // Format: Name:Rate:Price;Name:Rate:Price
          final additionalUnitsStr = row.length > 6 ? row[6]?.value?.toString() : null;
          if (additionalUnitsStr != null && additionalUnitsStr.isNotEmpty) {
            final unitParts = additionalUnitsStr.split(';');
            for (var part in unitParts) {
              final details = part.split(':');
              if (details.length >= 3) {
                units.add(ProductUnit(
                  id: _uuid.v4(),
                  productId: productId,
                  unitName: details[0].trim(),
                  conversionRate: double.tryParse(details[1]) ?? 1,
                  sellPrice: double.tryParse(details[2]) ?? 0,
                ));
              }
            }
          }

          productsToImport.add({product: units});
        }
      }

      if (productsToImport.isEmpty) {
        throw 'Tidak ada data produk yang valid ditemukan.';
      }

      setState(() => _status = 'Mengunggah ${productsToImport.length} produk...');
      await ref.read(productsProvider.notifier).importProducts(productsToImport);

      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Berhasil mengimpor ${productsToImport.length} produk');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _status = 'Error: $e';
        });
        showError(context, 'Gagal impor: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.file_upload_outlined, color: AppTheme.accent),
              const SizedBox(width: 12),
              Text('Import Produk dari Excel', style: Theme.of(context).textTheme.headlineMedium),
            ]),
            const SizedBox(height: 20),
            const Text('Gunakan format kolom berikut di Excel Anda:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A: Nama Produk (Wajib)', style: TextStyle(fontSize: 12)),
                  Text('B: Kategori', style: TextStyle(fontSize: 12)),
                  Text('C: Barcode', style: TextStyle(fontSize: 12)),
                  Text('D: Harga Dasar (Angka)', style: TextStyle(fontSize: 12)),
                  Text('E: Satuan Dasar (e.g. kg, pcs)', style: TextStyle(fontSize: 12)),
                  Text('F: Stok Awal (Angka)', style: TextStyle(fontSize: 12)),
                  Text('G: Satuan Lain (Format: Nama:Konversi:Harga;...)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contoh kolom G: roll:50:380000;box:6:540000',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_status!, style: TextStyle(color: _status!.startsWith('Error') ? AppTheme.danger : AppTheme.accent)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _importing ? null : _pickAndImport,
                  icon: _importing 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(_importing ? 'Memproses...' : 'Pilih File & Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
