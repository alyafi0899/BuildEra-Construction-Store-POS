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
  String _search = '';
  String? _categoryFilter;
  String _sortBy = 'name'; // 'name', 'category', 'cost', 'price', 'stock', 'profit'
  bool _sortAsc = true;
  final Set<String> _selectedIds = {};

  // New Filters
  String _stockFilter = 'all'; // 'all', 'in', 'low', 'out'
  String _supplierFilter = 'all'; // 'all', 'paid', 'unpaid'
  String _shippingFilter = 'all'; // 'all', 'paid', 'unpaid'

  bool _isGenerating = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
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
                    onChanged:  (v) => setState(() => _search = v),
                    onClear:    () => setState(() { _search = ''; _searchCtrl.clear(); }),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: DropdownButtonFormField<String?>(
                    initialValue:   _categoryFilter,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Kategori', isDense: true),
                    dropdownColor:  AppTheme.surfaceAlt,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                      ...AppConstants.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    initialValue:   _sortBy,
                    isExpanded:     true,
                    decoration:     const InputDecoration(labelText: 'Urutkan', isDense: true),
                    dropdownColor:  AppTheme.surfaceAlt,
                    items: const [
                      DropdownMenuItem(value: 'name',     child: Text('Nama (A-Z)')),
                      DropdownMenuItem(value: 'category', child: Text('Kategori')),
                      DropdownMenuItem(value: 'stock',    child: Text('Stok')),
                      DropdownMenuItem(value: 'cost',     child: Text('Harga Modal')),
                      DropdownMenuItem(value: 'price',    child: Text('Harga Jual')),
                      DropdownMenuItem(value: 'profit',   child: Text('Profit Satuan')),
                      DropdownMenuItem(value: 'created',  child: Text('Tanggal Dibuat')),
                      DropdownMenuItem(value: 'updated',  child: Text('Terakhir Diubah')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _sortAsc = !_sortAsc),
                  icon: Icon(_sortAsc ? Icons.south_rounded : Icons.north_rounded, color: AppTheme.accent),
                  tooltip: _sortAsc ? 'Ascending' : 'Descending',
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
                _FilterLabel('Stok:'),
                _FilterTab(label: 'Semua', selected: _stockFilter == 'all', onTap: () => setState(() => _stockFilter = 'all')),
                _FilterTab(label: 'Tersedia', selected: _stockFilter == 'in', onTap: () => setState(() => _stockFilter = 'in')),
                _FilterTab(label: 'Rendah', selected: _stockFilter == 'low', onTap: () => setState(() => _stockFilter = 'low')),
                _FilterTab(label: 'Habis', selected: _stockFilter == 'out', onTap: () => setState(() => _stockFilter = 'out')),
                
                const SizedBox(width: 24),
                _FilterLabel('Bayar Supplier:'),
                _FilterTab(label: 'Semua', selected: _supplierFilter == 'all', onTap: () => setState(() => _supplierFilter = 'all')),
                _FilterTab(label: 'Lunas', selected: _supplierFilter == 'paid', onTap: () => setState(() => _supplierFilter = 'paid')),
                _FilterTab(label: 'Belum', selected: _supplierFilter == 'unpaid', onTap: () => setState(() => _supplierFilter = 'unpaid')),

                const SizedBox(width: 24),
                _FilterLabel('Bayar Ongkir:'),
                _FilterTab(label: 'Semua', selected: _shippingFilter == 'all', onTap: () => setState(() => _shippingFilter = 'all')),
                _FilterTab(label: 'Lunas', selected: _shippingFilter == 'paid', onTap: () => setState(() => _shippingFilter = 'paid')),
                _FilterTab(label: 'Belum', selected: _shippingFilter == 'unpaid', onTap: () => setState(() => _shippingFilter = 'unpaid')),
              ]),
            ],
          ),
        ),

        // Table
        Expanded(child: productsAsync.when(
          loading: () => const AppLoading(),
          error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
          data:    (products) {
            // Apply Search & Category Filter
            var filtered = products.where((p) {
              final matchSearch = _search.isEmpty ||
                  p.name.toLowerCase().contains(_search.toLowerCase()) ||
                  (p.barcode?.contains(_search) ?? false);
              final matchCat = _categoryFilter == null || p.category == _categoryFilter;
              
              // New Filters
              bool matchStock = true;
              if (_stockFilter == 'in') matchStock = p.stock > 10;
              if (_stockFilter == 'low') matchStock = p.isLowStock && p.stock > 0;
              if (_stockFilter == 'out') matchStock = p.stock <= 0;
              
              bool matchSupplier = true;
              if (_supplierFilter == 'paid') matchSupplier = p.financials.supplierPaymentStatus == PaymentStatus.paid;
              if (_supplierFilter == 'unpaid') matchSupplier = p.financials.supplierPaymentStatus == PaymentStatus.unpaid;

              bool matchShipping = true;
              if (_shippingFilter == 'paid') matchShipping = p.financials.shippingPaymentStatus == PaymentStatus.paid;
              if (_shippingFilter == 'unpaid') matchShipping = p.financials.shippingPaymentStatus == PaymentStatus.unpaid;

              return matchSearch && matchCat && matchStock && matchSupplier && matchShipping;
            }).toList();

            // Apply Sorting
            filtered.sort((a, b) {
              int cmp;
              switch (_sortBy) {
                case 'category': cmp = a.category.compareTo(b.category); break;
                case 'stock':    cmp = a.stock.compareTo(b.stock); break;
                case 'cost':     cmp = a.costPrice.compareTo(b.costPrice); break;
                case 'price':    cmp = a.basePrice.compareTo(b.basePrice); break;
                case 'profit':   cmp = (a.basePrice - a.costPrice).compareTo(b.basePrice - b.costPrice); break;
                case 'created':  cmp = a.createdAt.compareTo(b.createdAt); break;
                case 'updated':  cmp = a.updatedAt.compareTo(b.updatedAt); break;
                default:         cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
              }
              return _sortAsc ? cmp : -cmp;
            });

            if (filtered.isEmpty) {
              return const EmptyState(
                icon:     Icons.inventory_2_outlined,
                title:    'Tidak ada produk',
                subtitle: 'Tambah produk pertama Anda',
              );
            }

            return _ProductTable(
              products: filtered,
              selectedIds: _selectedIds,
              onToggleSelect: _toggleSelect,
              onSelectAll: () => _toggleSelectAll(filtered),
            );
          },
        )),
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
                        widget.products.every((p) => widget.selectedIds.contains(p.id));

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Table header
          Container(
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
              _th('Produk',    flex: 4),
              _th('Kategori',  flex: 2),
              _th('Supplier & Ongkir', flex: 2),
              _th('Stok',      flex: 1, align: TextAlign.right),
              _th('Modal', flex: 1, align: TextAlign.right),
              _th('Harga Jual',  flex: 1, align: TextAlign.right),
              _th('Profit', flex: 1, align: TextAlign.right),
              _th('Aksi',      flex: 1, align: TextAlign.center),
            ]),
          ),
          // Rows
          ...widget.products.asMap().entries.map((e) => _ProductRow(
                product: e.value,
                isEven:  e.key.isEven,
                isSelected: widget.selectedIds.contains(e.value.id),
                onToggleSelect: () => widget.onToggleSelect(e.value.id),
              )),
        ]),
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

class _ProductRow extends ConsumerWidget {
  final Product product;
  final bool    isEven;
  final bool    isSelected;
  final VoidCallback onToggleSelect;

  const _ProductRow({
    required this.product,
    required this.isEven,
    required this.isSelected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profit = product.basePrice - product.costPrice;
    final f = product.financials;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:  isSelected 
          ? AppTheme.accent.withValues(alpha: 0.05) 
          : (isEven ? AppTheme.card : AppTheme.surface),
        border: Border(
          left:   BorderSide(color: isSelected ? AppTheme.accent : AppTheme.border),
          right:  BorderSide(color: isSelected ? AppTheme.accent : AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => onToggleSelect(),
            activeColor: AppTheme.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        // Product name + icon
        Expanded(flex: 4, child: InkWell(
          onTap: () => ProductDetailDialog.show(context, product),
          child: Row(children: [
            ProductImage(imagePath: product.imagePath, size: 36),
            const SizedBox(width: 12),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  Text(product.baseUnit, style: Theme.of(context).textTheme.bodySmall),
                  if (product.barcode != null) ...[
                    const SizedBox(width: 8),
                    Text('• ${product.barcode}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 10)),
                  ],
                ],
              ),
            ])),
          ]),
        )),
        Expanded(flex: 2, child: Text(product.category, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12))),
        
        // Supplier & Shipping Info
        Expanded(flex: 2, child: Column(
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
          if (product.isLowStock)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 14),
            ),
          Text(
            Formatters.decimal(product.stock),
            textAlign: TextAlign.right,
            style: TextStyle(
              color:      product.isLowStock ? AppTheme.warning : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ])),
        Expanded(flex: 1, child: Text(Formatters.currency(product.costPrice), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
        Expanded(flex: 1, child: Text(Formatters.currency(product.basePrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(flex: 1, child: Text(Formatters.currency(profit), textAlign: TextAlign.right, style: TextStyle(color: profit >= 0 ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12))),
        
        Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: () => ProductFormDialog.show(context, product: product),
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
            tooltip: 'Edit',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
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
          ),
        ])),
      ]),
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
