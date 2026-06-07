import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../providers/product_provider.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/excel_import_dialog.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _categoryFilter;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        // Top bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manajemen Produk', style: Theme.of(context).textTheme.headlineLarge),
              Text('Kelola daftar produk dan satuan jual', style: Theme.of(context).textTheme.bodyMedium),
            ]),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => ExcelImportDialog.show(context),
              icon:  const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import Excel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => ProductFormDialog.show(context),
              icon:  const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Produk'),
            ),
          ]),
        ),

        // Filters
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color:   AppTheme.surface,
          child:   Row(children: [
            SizedBox(
              width: 300,
              child: AppSearchField(
                controller: _searchCtrl,
                hintText:   'Cari produk atau barcode...',
                onChanged:  (v) => setState(() => _search = v),
                onClear:    () => setState(() { _search = ''; _searchCtrl.clear(); }),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value:          _categoryFilter,
                decoration:     const InputDecoration(labelText: 'Kategori'),
                dropdownColor:  AppTheme.surfaceAlt,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                  ...AppConstants.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _categoryFilter = v),
              ),
            ),
            const Spacer(),
            productsAsync.when(
              data: (p) => Text('${p.length} produk', style: Theme.of(context).textTheme.bodyMedium),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ]),
        ),

        // Table
        Expanded(child: productsAsync.when(
          loading: () => const AppLoading(),
          error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
          data:    (products) {
            final filtered = products.where((p) {
              final matchSearch = _search.isEmpty ||
                  p.name.toLowerCase().contains(_search.toLowerCase()) ||
                  (p.barcode?.contains(_search) ?? false);
              final matchCat = _categoryFilter == null || p.category == _categoryFilter;
              return matchSearch && matchCat;
            }).toList();

            if (filtered.isEmpty) {
              return const EmptyState(
                icon:     Icons.inventory_2_outlined,
                title:    'Tidak ada produk',
                subtitle: 'Tambah produk pertama Anda',
              );
            }

            return _ProductTable(products: filtered);
          },
        )),
      ]),
    );
  }
}

class _ProductTable extends ConsumerWidget {
  final List<Product> products;
  const _ProductTable({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scrollbar(
      child: SingleChildScrollView(
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
              _th('Produk',    flex: 4),
              _th('Kategori',  flex: 2),
              _th('Barcode',   flex: 2),
              _th('Stok',      flex: 1, align: TextAlign.right),
              _th('Harga Dasar', flex: 2, align: TextAlign.right),
              _th('Satuan Jual', flex: 3),
              _th('Aksi',      flex: 2, align: TextAlign.center),
            ]),
          ),
          // Rows
          ...products.asMap().entries.map((e) => _ProductRow(
                product: e.value,
                isEven:  e.key.isEven,
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
  const _ProductRow({required this.product, required this.isEven});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:  isEven ? AppTheme.card : AppTheme.surface,
        border: const Border(
          left:   BorderSide(color: AppTheme.border),
          right:  BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(children: [
        // Product name + icon
        Expanded(flex: 4, child: Row(children: [
          ProductImage(imagePath: product.imagePath, size: 36),
          const SizedBox(width: 12),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
            Text(product.baseUnit, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ])),
        Expanded(flex: 2, child: Text(product.category, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(flex: 2, child: Text(product.barcode ?? '—', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))),
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
            ),
          ),
        ])),
        Expanded(flex: 2, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(Formatters.currency(product.basePrice), style: Theme.of(context).textTheme.bodyMedium),
            if (product.defaultUnitName != null && product.defaultUnitName != product.baseUnit) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  product.defaultUnitName!,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        )),
        Expanded(flex: 3, child: Wrap(
          spacing: 4, runSpacing: 4,
          children: product.units.map((u) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
              border:       Border.all(color: AppTheme.border),
            ),
            child: Text(u.unitName, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          )).toList(),
        )),
        Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: () => ProductFormDialog.show(context, product: product),
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: 'Hapus Produk',
                  content: 'Yakin hapus "${product.name}"? Data tidak dapat dipulihkan.');
              if (!context.mounted) return;
              if (ok) {
                try {
                  await ref.read(productsProvider.notifier).deleteProduct(product.id);
                  if (context.mounted) showSuccess(context, 'Produk dihapus');
                } catch (e) {
                  if (context.mounted) showError(context, 'Gagal menghapus produk: $e');
                }
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 16, color: AppTheme.danger),
            tooltip: 'Hapus',
          ),
        ])),
      ]),
    );
  }
}
