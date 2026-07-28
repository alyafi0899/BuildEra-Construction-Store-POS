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
import '../../../inventory/providers/restock_provider.dart';
import '../../../inventory/models/restock_record.dart';
import '../../../inventory/presentation/widgets/restock_dialog.dart';
import '../../../../shared/widgets/security_gate.dart';

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

            // Stats row
            productsAsync.when(
              loading: () => const SizedBox(height: 100),
              error:   (_, __) => const SizedBox(),
              data: (products) {
                final lowStock  = products.where((p) => p.isLowStock).length;
                final totalSKU  = products.length;
                final outOfStock = products.where((p) => p.stock <= 0).length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  color: AppTheme.surface,
                  child: Row(children: [
                    Expanded(child: StatCard(label: 'Total SKU',     value: totalSKU.toString(),  icon: Icons.inventory_2_rounded)),
                    const SizedBox(width: 16),
                    Expanded(child: StatCard(label: 'Stok Rendah',  value: lowStock.toString(),   icon: Icons.warning_amber_rounded, accentColor: AppTheme.warning)),
                    const SizedBox(width: 16),
                    Expanded(child: StatCard(label: 'Habis',        value: outOfStock.toString(), icon: Icons.remove_shopping_cart_rounded, accentColor: AppTheme.danger)),
                  ]),
                );
              },
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
      trackVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: widget.products.length + 1, // Header + rows
        itemBuilder: (context, index) {
          if (index == 0) {
            // Table header
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
                    activeColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 32), // Added space for expand icon
                _th('Produk',    flex: 4),
                _th('Kategori',  flex: 1),
                _th('Supplier & Ongkir', flex: 1),
                _th('Stok',      flex: 1, align: TextAlign.right),
                _th('Modal', flex: 1, align: TextAlign.right),
                _th('Harga Jual',  flex: 1, align: TextAlign.right),
                _th('Profit', flex: 1, align: TextAlign.right),
                _th('Update Stok', flex: 1, align: TextAlign.center),
                _th('Aksi',      flex: 2, align: TextAlign.center),
              ]),
            );
          }

          final product = widget.products[index - 1];
          return RepaintBoundary(
            child: _ProductRow(
              key: ValueKey('prod_row_${product.id}'),
              product: product,
              isEven:  index.isEven,
              isSelected: widget.selectedIds.contains(product.id),
              onToggleSelect: () => widget.onToggleSelect(product.id),
            ),
          );
        },
      ),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          color:      AppTheme.textSecondary,
          fontSize:   12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProductRow extends ConsumerStatefulWidget {
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
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  bool _expanded = false;
  late final TextEditingController _adjCtrl;

  @override
  void initState() {
    super.initState();
    _adjCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _adjCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjust(double delta) async {
    await ref.read(productsActionProvider).adjustStock(widget.product.id, delta);
    _adjCtrl.clear();
    if (mounted) showSuccess(context, 'Stok diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final profit = widget.product.basePrice - widget.product.costPrice;
    final f = widget.product.financials;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:  widget.isSelected
                ? AppTheme.accent.withValues(alpha: 0.05)
                : (_expanded ? AppTheme.surfaceAlt.withValues(alpha: 0.1) : (widget.isEven ? AppTheme.card : AppTheme.surface)),
            border: Border(
              left:   BorderSide(color: widget.isSelected ? AppTheme.accent : AppTheme.border),
              right:  BorderSide(color: widget.isSelected ? AppTheme.accent : AppTheme.border),
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: widget.isSelected,
                onChanged: (_) => widget.onToggleSelect(),
                activeColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            
            // Expand Toggle
            IconButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, 
                size: 20, color: AppTheme.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),

            // Product name + icon
            Expanded(flex: 4, child: InkWell(
              onTap: () => ProductDetailDialog.show(context, widget.product),
              child: Row(children: [
                ProductImage(imagePath: widget.product.imagePath, size: 36),
                const SizedBox(width: 12),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(widget.product.baseUnit, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      if (widget.product.barcode != null) ...[
                        const SizedBox(width: 8),
                        Text('• ${widget.product.barcode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ],
                  ),
                ])),
              ]),
            )),
            Expanded(flex: 1, child: Text(widget.product.category, style: const TextStyle(fontSize: 12))),

            // Supplier & Shipping Info
            Expanded(flex: 1, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (f.supplierName != null)
                  _statusBadge(Icons.business_rounded, f.supplierName!, f.supplierPaymentStatus),
                if (f.shippingServiceName != null)
                  _statusBadge(Icons.local_shipping_rounded, f.shippingServiceName!, f.shippingPaymentStatus),
                if (f.supplierName == null && f.shippingServiceName == null)
                  const Text('—', style: TextStyle(color: AppTheme.textMuted)),
              ],
            )),

            Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (widget.product.isLowStock)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 14),
                ),
              Text(
                Formatters.decimal(widget.product.stock),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color:      widget.product.isLowStock ? AppTheme.warning : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ])),
            Expanded(flex: 1, child: BlurGate(child: Text(Formatters.currency(widget.product.costPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)))),
            Expanded(flex: 1, child: Text(Formatters.currency(widget.product.basePrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 1, child: BlurGate(child: Text(Formatters.currency(profit), textAlign: TextAlign.right, style: TextStyle(color: profit >= 0 ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12)))),

            // Update Stok Cepat (Dedicated Column)
            Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _adjCtrl,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  onSubmitted: (v) {
                    final val = double.tryParse(v);
                    if (val != null) _adjust(val);
                  },
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '±Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  final v = double.tryParse(_adjCtrl.text);
                  if (v != null) _adjust(v);
                },
                icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Terapkan Update Stok',
              ),
            ])),

            Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Restock Formal
              IconButton(
                onPressed: () => RestockDialog.show(context, widget.product),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppTheme.info),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Restock Formal',
              ),
              const SizedBox(width: 8),

              IconButton(
                onPressed: () => ProductFormDialog.show(context, product: widget.product),
                icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
                tooltip: 'Ubah Data Produk',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              _DeleteButton(product: widget.product),
            ])),
          ]),
        ),
        if (_expanded) _buildInventoryHub(widget.product),
      ],
    );
  }

  Widget _buildInventoryHub(Product p) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('RIWAYAT RESTOCK PRODUK', 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accent, letterSpacing: 1.1)),
              ],
            ),
          ),
          
          _buildHistoryList(p),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHistoryList(Product p) {
    final historyAsync = ref.watch(restockHistoryProvider);
    
    return historyAsync.when(
      data: (list) {
        final prodRecords = list.where((r) => r.productId == p.id).toList();
        if (prodRecords.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(56, 8, 16, 16),
            child: Text('Belum ada riwayat pengadaan untuk produk ini.', 
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
          );
        }

        return Column(
          children: prodRecords.map((r) => _RestockHistoryRow(record: r, product: p)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(56, 16, 16, 16),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(56, 8, 16, 16),
        child: Text('Gagal memuat riwayat'),
      ),
    );
  }

  Widget _statusBadge(IconData icon, String label, PaymentStatus status) {
    if (status == PaymentStatus.notApplicable) return const SizedBox();

    final color = status == PaymentStatus.paid ? AppTheme.success : AppTheme.warning;
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

class _RestockHistoryRow extends ConsumerWidget {
  final RestockRecord record;
  final Product product;
  const _RestockHistoryRow({required this.record, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Formatters.dateTime(record.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              if (record.notes != null)
                Text(record.notes!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('+${Formatters.decimal(record.quantityAdded)} ${record.unitName}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 13)),
              Text('Modal: ${Formatters.currency(record.totalCostPerUnit)}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (record.supplierName != null) _miniBadge(Icons.business_rounded, record.supplierName!, record.supplierPaymentStatus),
              if (record.shippingServiceName != null) _miniBadge(Icons.local_shipping_rounded, record.shippingServiceName!, record.shippingPaymentStatus),
            ]),
          ),
          const SizedBox(width: 16),
          // Actions
          IconButton(
            onPressed: () => RestockDialog.show(context, product, record: record),
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit Riwayat',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context, 
                title: 'Hapus Riwayat Restock', 
                content: 'Yakin hapus data ini? Stok akan dikurangi otomatis sesuai jumlah batch ini.');
              if (ok) {
                await ref.read(restockNotifierProvider.notifier).deleteRestock(record);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Hapus Riwayat',
          ),
        ]),
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label, PaymentStatus status) {
    final color = status == PaymentStatus.paid ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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
      icon: const Icon(Icons.delete_rounded, size: 16, color: AppTheme.danger),
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
    return Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted));
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppTheme.accent : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}