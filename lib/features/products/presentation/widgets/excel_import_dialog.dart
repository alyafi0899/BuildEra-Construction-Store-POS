import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';
import '../../providers/entity_provider.dart';
import '../../models/supplier.dart';
import '../../models/shipping_service.dart';
import '../../models/product_financials.dart';
import '../../../../shared/widgets/premium_guard.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_contacts.dart';

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
      final parseResult = await compute(_parseExcelIsolate, bytes);
      
      final productsToImport = parseResult.products;
      final uniqueSuppliers = parseResult.suppliers;

      if (productsToImport.isEmpty) {
        throw 'Tidak ada data produk yang valid ditemukan.';
      }

      setState(() => _status = 'Mendaftarkan ${uniqueSuppliers.length} supplier...');
      for (final s in uniqueSuppliers.values) {
        await ref.read(entityRepositoryProvider).saveSupplier(s);
      }
      
      setState(() => _status = 'Mendaftarkan ${parseResult.shipping.length} expedisi...');
      for (final s in parseResult.shipping.values) {
        await ref.read(entityRepositoryProvider).saveShippingService(s);
      }

      setState(() => _status = 'Mengunggah ${productsToImport.length} produk...');
      await ref.read(productsActionProvider).importProducts(productsToImport);

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
      child: PremiumGuard(
        featureName: 'Import Excel (Premium)',
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_upload_outlined, color: AppTheme.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Import Produk dari Excel',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (AppContacts.isConfigured(AppContacts.excelImportTemplateUrl)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Belum punya template?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Gunakan format ini agar impor berhasil.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(AppContacts.excelImportTemplateUrl);
                          if (uri == null) {
                            showError(context, 'Link template tidak valid.');
                            return;
                          }
                          if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
                              context.mounted) {
                            showError(context, 'Tidak dapat mengunduh format Excel saat ini.');
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Format Excel', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                    Text('B: Barcode', style: TextStyle(fontSize: 12)),
                    Text('C: Kategori', style: TextStyle(fontSize: 12)),
                    Text('D: Satuan Dasar (e.g. kg, pcs)', style: TextStyle(fontSize: 12)),
                    Text('E: Stok Awal', style: TextStyle(fontSize: 12)),
                    Text('F: Harga Modal (Rp)', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                    Text('G: Harga Jual Dasar (Rp)', style: TextStyle(fontSize: 12)),
                    Text('H: Nama Supplier (Opsional)', style: TextStyle(fontSize: 12)),
                    Text('I: No HP Supplier', style: TextStyle(fontSize: 12)),
                    Text('J: Alamat Supplier', style: TextStyle(fontSize: 12)),
                    Text('K: Nama Expedisi (Opsional)', style: TextStyle(fontSize: 12)),
                    Text('L: No HP Expedisi', style: TextStyle(fontSize: 12)),
                    Text('M: Alamat Expedisi', style: TextStyle(fontSize: 12)),
                  ],
                ),
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
      ),
    );
  }
}

class _ExcelParseResult {
  final List<Map<Product, List<ProductUnit>>> products;
  final Map<String, Supplier> suppliers;
  final Map<String, ShippingService> shipping;
  _ExcelParseResult(this.products, this.suppliers, this.shipping);
}

_ExcelParseResult _parseExcelIsolate(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final productsToImport = <Map<Product, List<ProductUnit>>>[];
  final uniqueSuppliers = <String, Supplier>{};
  final uniqueShipping = <String, ShippingService>{};
  final uuid = const Uuid();

  for (var table in excel.tables.keys) {
    final sheet = excel.tables[table]!;
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      String val(int idx) {
        if (idx >= row.length || row[idx] == null) return '';
        final cellValue = row[idx]!.value;
        if (cellValue == null) return '';
        return cellValue.toString().trim();
      }

      final name = val(0);
      if (name.isEmpty) continue;

      final barcode = val(1).isEmpty ? null : val(1);
      final category = val(2).isEmpty ? 'Lainnya' : val(2);
      final baseUnit = val(3).isEmpty ? 'pcs' : val(3);
      final stock = double.tryParse(val(4)) ?? 0.0;
      final costPrice = double.tryParse(val(5)) ?? 0.0;
      final basePrice = double.tryParse(val(6)) ?? 0.0;

      final supplierName = val(7);
      final supplierPhone = val(8);
      final supplierAddress = val(9);
      
      final shippingName = val(10);
      final shippingPhone = val(11);

      if (supplierName.isNotEmpty) {
        uniqueSuppliers[supplierName] = Supplier(
          id: uuid.v4(),
          name: supplierName,
          phone: supplierPhone.isEmpty ? null : supplierPhone,
          address: supplierAddress.isEmpty ? null : supplierAddress,
          createdAt: DateTime.now(),
        );
      }
      
      if (shippingName.isNotEmpty) {
        uniqueShipping[shippingName] = ShippingService(
          id: uuid.v4(),
          name: shippingName,
          phone: shippingPhone.isEmpty ? null : shippingPhone,
          createdAt: DateTime.now(),
        );
      }

      final product = Product(
        id: uuid.v4(),
        name: name,
        category: category,
        barcode: barcode,
        costPrice: costPrice,
        basePrice: basePrice,
        baseUnit: baseUnit,
        stock: stock,
        financials: ProductFinancials(
          supplierName: supplierName.isEmpty ? null : supplierName,
          supplierPaymentStatus: supplierName.isEmpty ? PaymentStatus.notApplicable : PaymentStatus.unpaid,
          shippingServiceName: shippingName.isEmpty ? null : shippingName,
          shippingPaymentStatus: shippingName.isEmpty ? PaymentStatus.notApplicable : PaymentStatus.unpaid,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      productsToImport.add({product: []});
    }
  }
  return _ExcelParseResult(productsToImport, uniqueSuppliers, uniqueShipping);
}
