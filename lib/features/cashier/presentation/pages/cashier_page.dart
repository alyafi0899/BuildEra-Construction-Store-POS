import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../widgets/barcode_listener.dart';
import '../widgets/cart_panel.dart';
import 'scanner_page.dart';

import '../../../../shared/widgets/product_detail_dialog.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(productCategoryFilterProvider);

    // Listen to global barcode events to update the local search field
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      
      // If a barcode was scanned while the field was focused, it likely wrote 
      // the barcode into the field. We clear it to prevent the scanner's 'Enter' 
      // from triggering the payment dialog.
      if (next.wasFocused) {
        _searchCtrl.text = next.barcode;
        _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: next.barcode.length),
        );
        ref.read(productSearchQueryProvider.notifier).set(next.barcode);
        return;
      }

      // Only react if NOT in focus, to update search results visually
      _searchCtrl.text = next.barcode;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: next.barcode.length),
      );
      ref.read(productSearchQueryProvider.notifier).set(next.barcode);
    });

    return BarcodeListener(
      autoAdd: true,
      child: Row(children: [
        // ── Left: Product Search & Grid ──────────────────────────────────
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Header
              PageHeader(
              title: 'Kasir',
              icon: Icons.point_of_sale_rounded,
              actions: [
                const SizedBox(width: 16),
                Text(Formatters.date(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            
            // Search Field (Separated from Header for consistency)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchField(
                      controller: _searchCtrl,
                      hintText: 'Cari produk atau scan barcode...',
                      onChanged: (v) => ref.read(productSearchQueryProvider.notifier).set(v),
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(productSearchQueryProvider.notifier).set('');
                      },
                      onSubmitted: (v) => ref.read(productSearchQueryProvider.notifier).set(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ScannerPage()),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48,
                        width: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
  
            // Category filter chips
            _CategoryFilter(
              selected: category,
              onSelected: (c) => ref.read(productCategoryFilterProvider.notifier).set(c),
            ),
  
            // Product grid
            const Expanded(
                child: _ProductGrid()),
          ]),
        ),
  
        // ── Right: Cart Panel ────────────────────────────────────────────
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(left: BorderSide(color: AppTheme.border)),
          ),
          child: const CartPanel(),
        ),
      ]),
    );
  }
}

// ── Category Filter ────────────────────────────────────────────────────────

class _CategoryFilter extends ConsumerWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _CategoryFilter({this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final categories =
        productsAsync.asData?.value.map((p) => p.category).toSet().toList() ??
            [];

    return Container(
      height: 48,
      color: AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _Chip(
              label: 'Semua',
              selected: selected == null,
              onTap: () => onSelected(null)),
          ...categories.map((c) => _Chip(
              label: c, selected: selected == c, onTap: () => onSelected(c))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product Grid ───────────────────────────────────────────────────────────

class _ProductGrid extends ConsumerStatefulWidget {
  const _ProductGrid();

  @override
  ConsumerState<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<_ProductGrid> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredProductsProvider);

    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Produk tidak ditemukan',
        subtitle: 'Coba kata kunci lain atau filter kategori',
      );
    }

    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      child: GridView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => _ProductCard(product: products[i]),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(cartProvider.notifier).addProduct(product),
        onLongPress: () => ProductDetailDialog.show(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with Info Button
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ProductImage(
                      imagePath: product.imagePath,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black38,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => ProductDetailDialog.show(context, product),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(product.basePrice),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 10,
                        color: product.isLowStock
                            ? AppTheme.danger
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${product.stock} ${product.baseUnit}',
                        style: TextStyle(
                          fontSize: 10,
                          color: product.isLowStock
                              ? AppTheme.danger
                              : AppTheme.textMuted,
                          fontWeight: product.isLowStock
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
