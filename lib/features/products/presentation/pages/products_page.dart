import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../../core/utils/barcode_helper.dart';
import '../../../../shared/widgets/product_detail_dialog.dart';
import '../../providers/barcode_history_provider.dart';
import '../../providers/product_provider.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/excel_import_dialog.dart';
import '../../models/product_financials.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isGenerating = false;

  @override
  void dispose() { 
    _searchCtrl.dispose(); 
    super.dispose(); 
  }

  void _toggleSelectAll(List<Product> products) {
    setState(() {
      final allVisibleSelected = products.every((p) => _selectedIds.contains(p.id));
      if (allVisibleSelected) {
        for (final p in products) {
          _selectedIds.remove(p.id);
        }
      } else {
        for (final p in products) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(context,
        title: 'Hapus Massal',
        content: 'Yakin hapus $count produk terpilih? Data tidak dapat dipulihkan.');
    
    if (!mounted) return;
    if (ok) {
      try {
        await ref.read(productsActionProvider).deleteProductsBatch(_selectedIds.toList());
        setState(() => _selectedIds.clear());
        if (mounted) showSuccess(context, '$count produk dihapus');
      } catch (e) {
        if (mounted) showError(context, 'Gagal menghapus produk: $e');
      }
    }
  }

  Future<void> _generateMissingBarcodes(List<Product> allProducts) async {
    final missing = allProducts.where((p) => p.barcode == null || p.barcode!.isEmpty).toList();
    if (missing.isEmpty) {
      showSuccess(context, 'Semua produk sudah memiliki barcode.');
      return;
    }

    final ok = await showConfirmDialog(context,
        title: 'Generate Barcode Massal',
        content: 'Akan membuat barcode unik untuk ${missing.length} produk. Lanjutkan?',
        confirmLabel: 'Generate',
        confirmColor: AppTheme.primary);
    
    if (!mounted || !ok) return;

    setState(() => _isGenerating = true);

    try {
      final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
      final productsAction = ref.read(productsActionProvider);
      final List<Product> updatedProducts = [];

      for (final product in missing) {
        String newBarcode = '';
        bool isUnique = false;
        int attempts = 0;

        while (!isUnique && attempts < 15) {
          final rawData = BarcodeHelper.generateRandomEAN13Data();
          newBarcode = BarcodeHelper.getEAN13WithCheckDigit(rawData);
          final used = await historyRepo.isBarcodeUsed(newBarcode);
          final duplicateInBatch = updatedProducts.any((p) => p.barcode == newBarcode);
          
          if (!used && !duplicateInBatch) isUnique = true;
          attempts++;
        }

        if (isUnique) {
          updatedProducts.add(product.copyWith(barcode: newBarcode));
        }
      }

      if (updatedProducts.isNotEmpty) {
        await productsAction.updateProductsBatch(updatedProducts);
        if (mounted) showSuccess(context, 'Berhasil membuat ${updatedProducts.length} barcode baru.');
      } else {
        if (mounted) showError(context, 'Tidak ada barcode unik yang berhasil dibuat.');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal generate barcode: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportToExcel(List<Product> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        TextCellValue('Nama Produk'),
        TextCellValue('Barcode'),
        TextCellValue('Kategori'),
        TextCellValue('Satuan Dasar'),
        TextCellValue('Stok Awal'),
        TextCellValue('Harga Modal (Rp)'),
        TextCellValue('Harga Jual Dasar (Rp)'),
        TextCellValue('Tanggal Dibuat'),
        TextCellValue('Terakhir Diubah'),
      ]);

      for (final p in products) {
        sheet.appendRow([
          TextCellValue(p.name),
          TextCellValue(p.barcode ?? ''),
          TextCellValue(p.category),
          TextCellValue(p.baseUnit),
          DoubleCellValue(p.stock),
          DoubleCellValue(p.costPrice),
          DoubleCellValue(p.basePrice),
          TextCellValue(Formatters.dateTime(p.createdAt)),
          TextCellValue(Formatters.dateTime(p.updatedAt)),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final now = DateTime.now();
      final fileName = 'Backup_Produk_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );

      if (mounted) showSuccess(context, 'Backup berhasil diekspor');
    } catch (e) {
      if (mounted) showError(context, 'Gagal ekspor: $e');
    }
  }

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isGenerating = false;

  @override
  void dispose() { 
    _searchCtrl.dispose(); 
    super.dispose(); 
  }

  void _toggleSelectAll(List<Product> products) {
    setState(() {
      final allVisibleSelected = products.every((p) => _selectedIds.contains(p.id));
      if (allVisibleSelected) {
        for (final p in products) {
          _selectedIds.remove(p.id);
        }
      } else {
        for (final p in products) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(context,
        title: 'Hapus Massal',
        content: 'Yakin hapus $count produk terpilih? Data tidak dapat dipulihkan.');
    
    if (!mounted) return;
    if (ok) {
      try {
        await ref.read(productsActionProvider).deleteProductsBatch(_selectedIds.toList());
        setState(() => _selectedIds.clear());
        if (mounted) showSuccess(context, '$count produk dihapus');
      } catch (e) {
        if (mounted) showError(context, 'Gagal menghapus produk: $e');
      }
    }
  }

  Future<void> _generateMissingBarcodes(List<Product> allProducts) async {
    final missing = allProducts.where((p) => p.barcode == null || p.barcode!.isEmpty).toList();
    if (missing.isEmpty) {
      showSuccess(context, 'Semua produk sudah memiliki barcode.');
      return;
    }

    final ok = await showConfirmDialog(context,
        title: 'Generate Barcode Massal',
        content: 'Akan membuat barcode unik untuk ${missing.length} produk. Lanjutkan?',
        confirmLabel: 'Generate',
        confirmColor: AppTheme.accent);
    
    if (!mounted || !ok) return;

    setState(() => _isGenerating = true);

    try {
      final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
      final productsAction = ref.read(productsActionProvider);
      final List<Product> updatedProducts = [];

      for (final product in missing) {
        String newBarcode = '';
        bool isUnique = false;
        int attempts = 0;

        while (!isUnique && attempts < 15) {
          final rawData = BarcodeHelper.generateRandomEAN13Data();
          newBarcode = BarcodeHelper.getEAN13WithCheckDigit(rawData);
          final used = await historyRepo.isBarcodeUsed(newBarcode);
          // Also check in our current batch to avoid duplicate within the same generation
          final duplicateInBatch = updatedProducts.any((p) => p.barcode == newBarcode);
          
          if (!used && !duplicateInBatch) isUnique = true;
          attempts++;
        }

        if (isUnique) {
          updatedProducts.add(product.copyWith(barcode: newBarcode));
        }
      }

      if (updatedProducts.isNotEmpty) {
        await productsAction.updateProductsBatch(updatedProducts);
        if (mounted) showSuccess(context, 'Berhasil membuat ${updatedProducts.length} barcode baru.');
      } else {
        if (mounted) showError(context, 'Tidak ada barcode unik yang berhasil dibuat.');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal generate barcode: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportToExcel(List<Product> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Header row matching the import format + metadata
      sheet.appendRow([
        TextCellValue('Nama Produk'),
        TextCellValue('Barcode'),
        TextCellValue('Kategori'),
        TextCellValue('Satuan Dasar'),
        TextCellValue('Stok Awal'),
        TextCellValue('Harga Modal (Rp)'),
        TextCellValue('Harga Jual Dasar (Rp)'),
        TextCellValue('Tanggal Dibuat'),
        TextCellValue('Terakhir Diubah'),
      ]);

      // Data rows
      for (final p in products) {
        sheet.appendRow([
          TextCellValue(p.name),
          TextCellValue(p.barcode ?? ''),
          TextCellValue(p.category),
          TextCellValue(p.baseUnit),
          DoubleCellValue(p.stock),
          DoubleCellValue(p.costPrice),
          DoubleCellValue(p.basePrice),
          TextCellValue(Formatters.dateTime(p.createdAt)),
          TextCellValue(Formatters.dateTime(p.updatedAt)),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final now = DateTime.now();
      final fileName = 'Backup_Produk_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );

      if (mounted) showSuccess(context, 'Backup berhasil diekspor');
    } catch (e) {
      if (mounted) showError(context, 'Gagal ekspor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final sortedProducts = ref.watch(sortedProductsProvider);
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final sort = ref.watch(productSortProvider);
    final filters = ref.watch(productFiltersProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
<<<<<<< HEAD
      body: Column(
        children: [
          PageHeader(
            title: 'Produk',
            subtitle: 'Kelola stok dan harga',
            icon: Icons.inventory_2_rounded,
            actions: [
              if (!isMobile) ...[
                OutlinedButton.icon(
                  onPressed: _isGenerating ? null : () => productsAsync.whenData((p) => _generateMissingBarcodes(p)),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Generate Missing'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ExcelImportDialog.show(context),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import'),
                ),
              ] else
                _MobileActionMenu(
                  onImport: () => ExcelImportDialog.show(context),
                  onExport: () => productsAsync.whenData((p) => _exportToExcel(p)),
                  onGenerate: _isGenerating ? null : () => productsAsync.whenData((p) => _generateMissingBarcodes(p)),
                ),
              if (_selectedIds.isNotEmpty)
                IconButton(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Cari produk...',
                  onChanged: (v) => ref.read(productSearchQueryProvider.notifier).set(v),
                  onClear: () {
                    _searchCtrl.clear();
                    ref.read(productSearchQueryProvider.notifier).set('');
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: categoryFilter ?? 'Semua Kategori',
                        onTap: () => _showCategoryPicker(context, ref),
                        icon: Icons.category_rounded,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Urut: ${_getSortLabel(sort.field)}',
                        onTap: () => _showSortPicker(context, ref, sort),
                        icon: Icons.sort_rounded,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Filter Stok',
                        onTap: () => _showStockFilterPicker(context, ref, filters),
                        icon: Icons.filter_alt_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: sortedProducts.isEmpty && productsAsync.isLoading
                ? const AppLoading()
                : sortedProducts.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Tidak ada produk',
                        subtitle: 'Sesuaikan pencarian atau tambah produk',
                      )
                    : isMobile
                        ? _ProductCardList(
                            products: sortedProducts,
                            selectedIds: _selectedIds,
                            onToggleSelect: _toggleSelect,
                          )
                        : _ProductTable(
                            products: sortedProducts,
                            selectedIds: _selectedIds,
                            onToggleSelect: _toggleSelect,
                            onSelectAll: () => _toggleSelectAll(sortedProducts),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ProductFormDialog.show(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  String _getSortLabel(ProductSortField field) {
    switch (field) {
      case ProductSortField.name: return 'Nama';
      case ProductSortField.stock: return 'Stok';
      case ProductSortField.created: return 'Terbaru';
      default: return field.name;
    }
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Semua Kategori'),
                    onTap: () {
                      ref.read(productCategoryFilterProvider.notifier).set(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...AppConstants.categories.map((c) => ListTile(
                    title: Text(c),
                    onTap: () {
                      ref.read(productCategoryFilterProvider.notifier).set(c);
                      Navigator.pop(context);
                    },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortPicker(BuildContext context, WidgetRef ref, ProductSort current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Urutkan Berdasarkan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('Nama (A-Z)'),
            onTap: () {
              ref.read(productSortProvider.notifier).setField(ProductSortField.name);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Stok Terendah'),
            onTap: () {
              ref.read(productSortProvider.notifier).setField(ProductSortField.stock);
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Terbaru'),
            onTap: () {
              ref.read(productSortProvider.notifier).setField(ProductSortField.created);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showStockFilterPicker(BuildContext context, WidgetRef ref, ProductFilters filters) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const Divider(),
          _SubLabel('STOK'),
          _stockFilterTile(context, ref, 'Semua Stok', 'all', filters.stock),
          _stockFilterTile(context, ref, 'Tersedia', 'in', filters.stock),
          _stockFilterTile(context, ref, 'Stok Rendah', 'low', filters.stock),
          _stockFilterTile(context, ref, 'Habis', 'out', filters.stock),
          const Divider(),
          _SubLabel('PEMBAYARAN SUPPLIER'),
          _supplierFilterTile(context, ref, 'Semua', 'all', filters.supplier),
          _supplierFilterTile(context, ref, 'Lunas', 'paid', filters.supplier),
          _supplierFilterTile(context, ref, 'Belum Lunas', 'unpaid', filters.supplier),
          const Divider(),
          _SubLabel('PEMBAYARAN ONGKIR'),
          _shippingFilterTile(context, ref, 'Semua', 'all', filters.shipping),
          _shippingFilterTile(context, ref, 'Lunas', 'paid', filters.shipping),
          _shippingFilterTile(context, ref, 'Belum Lunas', 'unpaid', filters.shipping),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stockFilterTile(BuildContext context, WidgetRef ref, String label, String val, String current) {
    return ListTile(
      title: Text(label),
      trailing: val == current ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
      onTap: () {
        ref.read(productFiltersProvider.notifier).setStock(val);
        Navigator.pop(context);
      },
    );
  }

  Widget _supplierFilterTile(BuildContext context, WidgetRef ref, String label, String val, String current) {
    return ListTile(
      title: Text(label),
      trailing: val == current ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
      onTap: () {
        ref.read(productFiltersProvider.notifier).setSupplier(val);
        Navigator.pop(context);
      },
    );
  }

  Widget _shippingFilterTile(BuildContext context, WidgetRef ref, String label, String val, String current) {
    return ListTile(
      title: Text(label),
      trailing: val == current ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
      onTap: () {
        ref.read(productFiltersProvider.notifier).setShipping(val);
        Navigator.pop(context);
      },
    );
  }
}

class _MobileActionMenu extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback? onGenerate;

  const _MobileActionMenu({required this.onImport, required this.onExport, this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Import Excel'))),
        const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.download), title: Text('Export Excel'))),
        const PopupMenuItem(value: 'generate', child: ListTile(leading: Icon(Icons.auto_fix_high), title: Text('Generate Barcodes'))),
      ],
      onSelected: (val) {
        if (val == 'import') onImport();
        if (val == 'export') onExport();
        if (val == 'generate' && onGenerate != null) onGenerate!();
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const _FilterChip({required this.label, required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: AppTheme.primary),
      label: Text(label),
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ProductCardList extends StatelessWidget {
  final List<Product> products;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;

  const _ProductCardList({
    required this.products,
    required this.selectedIds,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductMobileCard(
          product: product,
          isSelected: selectedIds.contains(product.id),
          onTap: () => ProductDetailDialog.show(context, product),
          onLongPress: () => onToggleSelect(product.id),
        );
      },
    );
  }
}

class _ProductMobileCard extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProductMobileCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : null,
      onTap: onTap,
      child: InkWell(
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImage(imagePath: product.imagePath, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(product.category, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoBadge(Formatters.currency(product.basePrice), AppTheme.primary),
                        const SizedBox(width: 8),
                        _infoBadge('Stok: ${Formatters.decimal(product.stock)}', product.isLowStock ? AppTheme.danger : AppTheme.success),
                      ],
                    ),
                  ],
=======
      body: PinGate(
        child: Column(
          children: [
            // Top bar
            PageHeader(
          title: 'Manajemen Produk',
          subtitle: 'Kelola daftar produk dan satuan jual',
          icon: Icons.inventory_2_rounded,
          actions: [
            if (_isGenerating)
              const Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                  ),
                  SizedBox(width: 12),
                  Text('Generating Barcodes...', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            OutlinedButton.icon(
              onPressed: _isGenerating ? null : () => productsAsync.whenData((p) => _generateMissingBarcodes(p)),
              icon:  const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Generate Missing'),
            ),
            OutlinedButton.icon(
              onPressed: () => ExcelImportDialog.show(context),
              icon:  const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => productsAsync.whenData((p) => _exportToExcel(p)),
              icon:  const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export Excel'),
            ),
            ElevatedButton.icon(
              onPressed: () => ProductFormDialog.show(context),
              icon:  const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Produk'),
            ),
          ],
        ),

        // Filters & Sorting
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color:   AppTheme.surface,
          child:   Column(
            children: [
              Row(children: [
                SizedBox(
                  width: 260,
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText:   'Cari produk atau barcode...',
                    onChanged:  (v) => ref.read(productSearchQueryProvider.notifier).set(v),
                    onClear:    () {
                      _searchCtrl.clear();
                      ref.read(productSearchQueryProvider.notifier).set('');
                    },
                  ),
>>>>>>> parent of bd29cdf (fixing bug)
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: DropdownButtonFormField<String?>(
                    initialValue:   categoryFilter,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Kategori', isDense: true),
                    dropdownColor:  AppTheme.surfaceAlt,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                      ...AppConstants.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => ref.read(productCategoryFilterProvider.notifier).set(v),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: DropdownButtonFormField<ProductSortField>(
                    initialValue:   sort.field,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Urutkan', isDense: true),
                    dropdownColor:  AppTheme.surfaceAlt,
                    items: const [
                      DropdownMenuItem(value: ProductSortField.name,     child: Text('Nama (A-Z)')),
                      DropdownMenuItem(value: ProductSortField.category, child: Text('Kategori')),
                      DropdownMenuItem(value: ProductSortField.stock,    child: Text('Stok')),
                      DropdownMenuItem(value: ProductSortField.cost,     child: Text('Harga Modal')),
                      DropdownMenuItem(value: ProductSortField.price,    child: Text('Harga Jual')),
                      DropdownMenuItem(value: ProductSortField.profit,   child: Text('Profit Satuan')),
                      DropdownMenuItem(value: ProductSortField.created,  child: Text('Tanggal Dibuat')),
                      DropdownMenuItem(value: ProductSortField.updated,  child: Text('Terakhir Diubah')),
                    ],
                    onChanged: (v) => ref.read(productSortProvider.notifier).setField(v!),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ref.read(productSortProvider.notifier).toggleOrder(),
                  icon: Icon(sort.ascending ? Icons.south_rounded : Icons.north_rounded, color: AppTheme.accent),
                  tooltip: sort.ascending ? 'Ascending' : 'Descending',
                ),
                const SizedBox(width: 16),
                if (_selectedIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _bulkDelete,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text('Hapus (${_selectedIds.length})'),
                  ),
                const Spacer(),
                productsAsync.when(
                  data: (p) => Text('${p.length} produk', style: Theme.of(context).textTheme.bodySmall),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                const _FilterLabel('Stok:'),
                _FilterTab(label: 'Semua', selected: filters.stock == 'all', onTap: () => ref.read(productFiltersProvider.notifier).setStock('all')),
                _FilterTab(label: 'Tersedia', selected: filters.stock == 'in', onTap: () => ref.read(productFiltersProvider.notifier).setStock('in')),
                _FilterTab(label: 'Rendah', selected: filters.stock == 'low', onTap: () => ref.read(productFiltersProvider.notifier).setStock('low')),
                _FilterTab(label: 'Habis', selected: filters.stock == 'out', onTap: () => ref.read(productFiltersProvider.notifier).setStock('out')),
                
                const SizedBox(width: 24),
                const _FilterLabel('Bayar Supplier:'),
                _FilterTab(label: 'Semua', selected: filters.supplier == 'all', onTap: () => ref.read(productFiltersProvider.notifier).setSupplier('all')),
                _FilterTab(label: 'Lunas', selected: filters.supplier == 'paid', onTap: () => ref.read(productFiltersProvider.notifier).setSupplier('paid')),
                _FilterTab(label: 'Belum', selected: filters.supplier == 'unpaid', onTap: () => ref.read(productFiltersProvider.notifier).setSupplier('unpaid')),

                const SizedBox(width: 24),
                const _FilterLabel('Bayar Ongkir:'),
                _FilterTab(label: 'Semua', selected: filters.shipping == 'all', onTap: () => ref.read(productFiltersProvider.notifier).setShipping('all')),
                _FilterTab(label: 'Lunas', selected: filters.shipping == 'paid', onTap: () => ref.read(productFiltersProvider.notifier).setShipping('paid')),
                _FilterTab(label: 'Belum', selected: filters.shipping == 'unpaid', onTap: () => ref.read(productFiltersProvider.notifier).setShipping('unpaid')),
              ]),
            ],
          ),
        ),

        // Table
        Expanded(
          child: sortedProducts.isEmpty && productsAsync.isLoading
            ? const AppLoading()
            : sortedProducts.isEmpty 
              ? const EmptyState(
                  icon:     Icons.inventory_2_outlined,
                  title:    'Tidak ada produk',
                  subtitle: 'Tambah produk pertama Anda atau sesuaikan filter',
                )
              : _ProductTable(
                  products: sortedProducts,
                  selectedIds: _selectedIds,
                  onToggleSelect: _toggleSelect,
                  onSelectAll: () => _toggleSelectAll(sortedProducts),
                ),
        ),
          ],
        ),
      ),
    );
  }
}

class _ProductTable extends StatefulWidget {
  final List<Product> products;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onSelectAll;

  const _ProductTable({
    required this.products,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onSelectAll,
  });

  @override
  State<_ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<_ProductTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = widget.products.isNotEmpty && 
                        widget.selectedIds.length == widget.products.length;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: widget.products.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:        AppTheme.surfaceAlt,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border:       Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: (_) => widget.onSelectAll(),
                    activeColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                _th('Produk',    flex: 4),
                _th('Kategori',  flex: 2),
                _th('Stok',      flex: 1, align: TextAlign.right),
                _th('Harga Jual',  flex: 1, align: TextAlign.right),
                _th('Aksi',      flex: 1, align: TextAlign.center),
              ]),
            );
          }

          final product = widget.products[index - 1];
          return _ProductRow(
            key: ValueKey('prod_row_${product.id}'),
            product: product,
            isSelected: widget.selectedIds.contains(product.id),
            onToggleSelect: () => widget.onToggleSelect(product.id),
          );
        },
      ),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label, textAlign: align, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  const _ProductRow({super.key, required this.product, required this.isSelected, required this.onToggleSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:  isSelected ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => onToggleSelect(),
            activeColor: AppTheme.primary,
          ),
        ),
        Expanded(flex: 4, child: InkWell(
          onTap: () => ProductDetailDialog.show(context, product),
          child: Row(children: [
            ProductImage(imagePath: product.imagePath, size: 36),
            const SizedBox(width: 12),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              Text(product.baseUnit, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ])),
          ]),
        )),
        Expanded(flex: 2, child: Text(product.category, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 1, child: Text(Formatters.decimal(product.stock), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 1, child: Text(Formatters.currency(product.basePrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => ProductFormDialog.show(context, product: product), icon: const Icon(Icons.edit_rounded, size: 16)),
          IconButton(onPressed: () => _delete(context), icon: const Icon(Icons.delete_rounded, size: 16, color: AppTheme.danger)),
        ])),
      ]),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(context, title: 'Hapus', content: 'Yakin hapus ${product.name}?');
    if (ok) { /* Action handled by provider usually */ }
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(text, style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
    );
  }
}
