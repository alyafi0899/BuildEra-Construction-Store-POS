import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/products/providers/product_provider.dart';
import 'package:buildera/features/products/providers/barcode_history_provider.dart';
import 'package:buildera/shared/models/product.dart';
import 'package:uuid/uuid.dart';
import 'package:buildera/core/utils/formatters.dart';

class ExcelImportDialog extends ConsumerStatefulWidget {
  const ExcelImportDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ExcelImportDialog(),
    );
  }

  @override
  ConsumerState<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends ConsumerState<ExcelImportDialog> {
  PlatformFile? _file;
  bool _isImporting = false;
  List<Product>? _previewData;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      setState(() => _file = result.files.first);
      _processPreview();
    }
  }

  Future<void> _processPreview() async {
    if (_file == null || _file!.path == null) return;
    
    setState(() => _isImporting = true);
    try {
      final bytes = File(_file!.path!).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final List<Product> products = [];
      final uuid = const Uuid();

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        for (var i = 1; i < sheet.maxRows; i++) {
          final row = sheet.row(i);
          if (row.isEmpty || row[0] == null) continue;

          final name = row[0]?.value?.toString() ?? '';
          if (name.isEmpty) continue;

          products.add(Product(
            id: uuid.v4(),
            name: name,
            barcode: row[1]?.value?.toString(),
            category: row[2]?.value?.toString() ?? 'Umum',
            baseUnit: row[3]?.value?.toString() ?? 'pcs',
            stock: double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0,
            costPrice: double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0,
            basePrice: double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }
      setState(() => _previewData = products);
    } catch (e) {
      if (mounted) showError(context, 'Gagal membaca file: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _import() async {
    if (_previewData == null || _previewData!.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final productsAction = ref.read(productsActionProvider);
      final barcodeHistory = ref.read(barcodeHistoryRepositoryProvider);

      final List<Map<Product, List<ProductUnit>>> batchData = _previewData!
          .map((p) => {p: <ProductUnit>[]})
          .toList();

      await productsAction.importProducts(batchData);

      final barcodes = _previewData!
          .where((p) => p.barcode != null && p.barcode!.isNotEmpty)
          .map((p) => (barcode: p.barcode!, name: p.name, id: p.id))
          .toList();
      
      if (barcodes.isNotEmpty) {
        await barcodeHistory.logBarcodesBatch(barcodes);
      }

      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Berhasil mengimpor ${_previewData!.length} produk');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal impor: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(Icons.file_upload_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text('Import Produk dari Excel', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const Divider(height: 32),
            
            if (_previewData == null) ...[
              const Text('Pilih file Excel (.xlsx) dengan format kolom:', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Nama, Barcode, Kategori, Satuan, Stok, Harga Modal, Harga Jual', 
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _pickFile,
                icon: const Icon(Icons.search_rounded),
                label: const Text('CARI FILE EXCEL'),
              ),
            ] else ...[
              Text('Pratinjau Data: ${_previewData!.length} Produk Terdeteksi', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  itemCount: _previewData!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _previewData![i];
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.category} • ${p.baseUnit} • Stok: ${p.stock}', style: const TextStyle(fontSize: 11)),
                      trailing: Text(Formatters.currency(p.basePrice), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _previewData = null),
                      child: const Text('GANTI FILE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isImporting ? null : _import,
                      child: _isImporting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('MULAI IMPORT'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
