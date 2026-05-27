// lib/features/products/presentation/pages/products_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import '../widgets/product_form_dialog.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(allProductsProvider);
    final query = ref.watch(productSearchQueryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Manajemen Produk',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${products.length} produk terdaftar',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Produk'),
            ),
          ]),
        ),

        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: SearchField(
                controller: _searchCtrl,
                hintText: 'Cari produk berdasarkan nama atau barcode...',
                onChanged: (v) => ref.read(productSearchQueryProvider.notifier).state = v,
                onClear: () {
                  ref.read(productSearchQueryProvider.notifier).state = '';
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCategory ?? 'Semua',
                decoration: const InputDecoration(labelText: 'Kategori'),
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                items: ['Semua', ...{...products.map((p) => p.category)}]
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v == 'Semua' ? null : v),
              ),
            ),
          ]),
        ),

        // Table
        Expanded(
          child: _buildTable(context, products, query),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<ProductEntity> products, String query) {
    var filtered = products;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false)).toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: query.isNotEmpty ? 'Produk tidak ditemukan' : 'Belum ada produk',
        subtitle: query.isNotEmpty ? 'Coba kata kunci yang berbeda' : 'Klik "Tambah Produk" untuk memulai',
        action: query.isEmpty
            ? ElevatedButton.icon(
                onPressed: () => _showForm(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Tambah Produk'),
              )
            : null,
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(children: [
              Expanded(flex: 4, child: _H('Produk')),
              Expanded(flex: 2, child: _H('Kategori')),
              Expanded(flex: 2, child: _H('Barcode')),
              Expanded(flex: 2, child: _H('Harga Dasar')),
              Expanded(flex: 2, child: _H('Stok')),
              Expanded(flex: 2, child: _H('Satuan')),
              Expanded(flex: 2, child: _H('Status')),
              SizedBox(width: 80),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) => _ProductRow(
                product: filtered[i],
                onEdit: (p) => _showForm(context, product: p),
                onDelete: (p) => _delete(context, p),
              ).animate(delay: Duration(milliseconds: 20 * i)).fadeIn(duration: 200.ms),
            ),
          ),
        ]),
      ),
    );
  }

  void _showForm(BuildContext context, {ProductEntity? product}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ProductFormDialog(product: product),
    );
  }

  Future<void> _delete(BuildContext context, ProductEntity product) async {
    final ok = await showConfirmDialog(context,
        title: 'Hapus Produk',
        message: 'Hapus "${product.name}"? Tindakan ini tidak dapat dibatalkan.');
    if (!ok) return;
    if (!mounted) return;
    final success = await ref.read(productNotifierProvider.notifier).deleteProduct(product.id!);
    if (!mounted) return;
    if (success) {
      showSuccessSnackbar(context, '${product.name} berhasil dihapus');
    } else {
      showErrorSnackbar(context, 'Gagal menghapus produk');
    }
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _ProductRow extends StatefulWidget {
  final ProductEntity product;
  final ValueChanged<ProductEntity> onEdit;
  final ValueChanged<ProductEntity> onDelete;
  const _ProductRow({required this.product, required this.onEdit, required this.onDelete});
  @override State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hov ? AppColors.surfaceVariant.withValues(alpha: 0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Product
          Expanded(flex: 4, child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.construction_rounded, color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (p.description != null)
                Text(p.description!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ])),
          // Category
          Expanded(flex: 2, child: _chip(p.category)),
          // Barcode
          Expanded(flex: 2, child: Text(p.barcode ?? '-',
              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace', fontSize: 12))),
          // Price
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(p.basePrice),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          // Stock
          Expanded(flex: 2, child: Text(
            '${AppFormatters.formatQuantity(p.stockQuantity)} ${p.baseUnit}',
            style: TextStyle(
              color: p.isOutOfStock ? AppColors.error : p.isLowStock ? AppColors.warning : AppColors.textPrimary,
              fontWeight: FontWeight.w600, fontSize: 13),
          )),
          // Units
          Expanded(flex: 2, child: Text(p.units.map((u) => u.unitName).join(', '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          // Status
          Expanded(flex: 2, child: p.isOutOfStock ? StatusBadge.outOfStock()
              : p.isLowStock ? StatusBadge.lowStock() : StatusBadge.inStock()),
          // Actions
          SizedBox(width: 80, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(onPressed: () => widget.onEdit(p), icon: const Icon(Icons.edit_rounded, size: 16),
                color: AppColors.textSecondary, tooltip: 'Edit', visualDensity: VisualDensity.compact),
            IconButton(onPressed: () => widget.onDelete(p), icon: const Icon(Icons.delete_outline_rounded, size: 16),
                color: AppColors.error, tooltip: 'Hapus', visualDensity: VisualDensity.compact),
          ])),
        ]),
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
    child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}
