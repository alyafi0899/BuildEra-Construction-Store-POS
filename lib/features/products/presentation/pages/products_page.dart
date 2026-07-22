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
import '../../../../shared/widgets/security_gate.dart';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final sortedProducts = ref.watch(sortedProductsProvider);
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final sort = ref.watch(productSortProvider);
    final filters = ref.watch(productFiltersProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: PinGate(
        child: Column(
          children: [
            // Top bar
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
                ],
                if (isMobile && _selectedIds.isNotEmpty)
                  IconButton(
                    onPressed: _bulkDelete,
                    icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger),
                  ),
              ],
            ),

            // Search and Filters
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
                          label: 'Urut: ${sort.field.name}',
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

            // List or Table
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ProductFormDialog.show(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
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

  void _showSortPicker(BuildContext context, WidgetRef ref, ProductSortState current) {
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
            child: Text('Filter Stok', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _stockFilterTile(context, ref, 'Semua', 'all', filters.stock),
          _stockFilterTile(context, ref, 'Tersedia', 'in', filters.stock),
          _stockFilterTile(context, ref, 'Stok Rendah', 'low', filters.stock),
          _stockFilterTile(context, ref, 'Habis', 'out', filters.stock),
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
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
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
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  Text(product.baseUnit, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  if (product.barcode != null) ...[
                    const SizedBox(width: 8),
                    Text('• ${product.barcode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ],
              ),
            ])),
          ]),
        )),
        Expanded(flex: 2, child: Text(product.category, style: const TextStyle(fontSize: 12))),
        
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
        Expanded(flex: 1, child: BlurGate(child: Text(Formatters.currency(product.costPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)))),
        Expanded(flex: 1, child: Text(Formatters.currency(product.basePrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(flex: 1, child: BlurGate(child: Text(Formatters.currency(profit), textAlign: TextAlign.right, style: TextStyle(color: profit >= 0 ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12)))),
        
        Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: () => ProductFormDialog.show(context, product: product),
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
            tooltip: 'Edit',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          _DeleteButton(product: product),
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
