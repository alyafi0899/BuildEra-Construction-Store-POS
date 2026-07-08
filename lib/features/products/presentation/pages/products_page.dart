import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
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

    final colorScheme = Theme.of(context).colorScheme;
    final ok = await showConfirmDialog(context,
        title: 'Generate Barcode Massal',
        content: 'Akan membuat barcode unik untuk ${missing.length} produk. Lanjutkan?',
        confirmLabel: 'Generate',
        confirmColor: colorScheme.primary);
    
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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final sortedProducts = ref.watch(sortedProductsProvider);
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final sort = ref.watch(productSortProvider);
    final filters = ref.watch(productFiltersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          PageHeader(
          title: 'Manajemen Produk',
          subtitle: 'Kelola daftar produk dan satuan jual',
          icon: Icons.inventory_2_rounded,
          actions: [
            if (_isGenerating)
              Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Generating Barcodes...', style: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
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
          color:   colorScheme.surface,
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
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: DropdownButtonFormField<String?>(
                    value:          categoryFilter,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Kategori', isDense: true),
                    dropdownColor:  colorScheme.surface,
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
                    value:          sort.field,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Urutkan', isDense: true),
                    dropdownColor:  colorScheme.surface,
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
                  icon: Icon(sort.ascending ? Icons.south_rounded : Icons.north_rounded, color: colorScheme.primary),
                  tooltip: sort.ascending ? 'Ascending' : 'Descending',
                ),
                const SizedBox(width: 16),
                if (_selectedIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _bulkDelete,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
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
                Icon(Icons.filter_list_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
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
      ]),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: widget.products.length + 1, // Header + rows
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:        colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border:       Border.all(color: colorScheme.outline),
              ),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: (_) => widget.onSelectAll(),
                    activeColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                _th('Produk',    flex: 4),
                _th('Kategori',  flex: 2),
                _th('Supplier & Ongkir', flex: 2),
                _th('Stok',      flex: 1, align: TextAlign.right),
                _th('Modal', flex: 1, align: TextAlign.right),
                _th('Harga Jual',  flex: 1, align: TextAlign.right),
                _th('Profit', flex: 1, align: TextAlign.right),
                _th('Aksi',      flex: 1, align: TextAlign.center),
              ]),
            );
          }

          final product = widget.products[index - 1];
          return _ProductRow(
            key: ValueKey('prod_row_${product.id}'),
            product: product,
            isEven:  index.isEven,
            isSelected: widget.selectedIds.contains(product.id),
            onToggleSelect: () => widget.onToggleSelect(product.id),
          );
        },
      ),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          color:      colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize:   12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final bool    isEven;
  final bool    isSelected;
  final VoidCallback onToggleSelect;

  const _ProductRow({
    super.key,
    required this.product,
    required this.isEven,
    required this.isSelected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final profit = product.basePrice - product.costPrice;
    final f = product.financials;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left:   BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outline),
          right:  BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outline),
          bottom: BorderSide(color: colorScheme.outline),
        ),
      ),
      child: Material(
        color:  isSelected 
          ? colorScheme.primary.withValues(alpha: 0.05) 
          : (isEven ? colorScheme.surface : colorScheme.surfaceContainerHighest),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelect(),
                activeColor: colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Expanded(flex: 4, child: InkWell(
              onTap: () => ProductDetailDialog.show(context, product),
              child: Row(children: [
                ProductImage(imagePath: product.imagePath, size: 36),
                const SizedBox(width: 12),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(product.baseUnit, style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      if (product.barcode != null) ...[
                        const SizedBox(width: 8),
                        Text('• ${product.barcode}', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                      ],
                    ],
                  ),
                ])),
              ]),
            )),
            Expanded(flex: 2, child: Text(product.category, style: const TextStyle(fontSize: 12))),
            
            Expanded(flex: 2, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (f.supplierName != null)
                  _statusBadge(context, Icons.business_rounded, f.supplierName!, f.supplierPaymentStatus),
                if (f.shippingServiceName != null)
                  _statusBadge(context, Icons.local_shipping_rounded, f.shippingServiceName!, f.shippingPaymentStatus),
                if (f.supplierName == null && f.shippingServiceName == null)
                  Text('—', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            )),

            Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (product.isLowStock)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.warning_amber_rounded, color: colorScheme.secondary, size: 14),
                ),
              Text(
                Formatters.decimal(product.stock),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color:      product.isLowStock ? colorScheme.secondary : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ])),
            Expanded(flex: 1, child: Text(Formatters.currency(product.costPrice), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)))),
            Expanded(flex: 1, child: Text(Formatters.currency(product.basePrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 1, child: Text(Formatters.currency(profit), textAlign: TextAlign.right, style: TextStyle(color: profit >= 0 ? const Color(0xFF2ECC71) : colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12))),
            
            Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: () => ProductFormDialog.show(context, product: product),
                icon: Icon(Icons.edit_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              _DeleteButton(product: product),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, IconData icon, String label, PaymentStatus status) {
    if (status == PaymentStatus.notApplicable) return const SizedBox();
    final colorScheme = Theme.of(context).colorScheme;
    final color = status == PaymentStatus.paid ? const Color(0xFF2ECC71) : colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, 
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteButton extends ConsumerWidget {
  final Product product;
  const _DeleteButton({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () async {
        final ok = await showConfirmDialog(context,
            title: 'Hapus Produk',
            content: 'Yakin hapus "${product.name}"? Data Termasuk:\n-Tagihan Supplier\n-Tagihan Expedisi\ntidak dapat dipulihkan.');
        if (ok) {
          try {
            await ref.read(productsActionProvider).deleteProduct(product.id);
            if (context.mounted) showSuccess(context, 'Produk dihapus');
          } catch (e) {
            if (context.mounted) showError(context, 'Gagal menghapus produk: $e');
          }
        }
      },
      icon: Icon(Icons.delete_rounded, size: 16, color: colorScheme.error),
      tooltip: 'Hapus',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;
  const _FilterLabel(this.label);
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.5)));
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline),
          ),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
      ),
    );
  }
}
