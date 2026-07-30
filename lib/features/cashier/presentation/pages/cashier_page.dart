import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../products/providers/product_provider.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/multi_cart_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/cart_panel.dart';
import '../widgets/barcode_listener.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredProductsProvider);
    final productsAsync = ref.watch(productsProvider);

    if (products.isEmpty) {
      if (productsAsync.isLoading) return const AppLoading();
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Produk tidak ditemukan',
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => RepaintBoundary(
          child: _ProductListTile(
            key: ValueKey('cashier_prod_${products[i].id}'),
            product: products[i],
          ),
        ),
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  final Product product;
  const _ProductListTile({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.isLowStock;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(cartProvider.notifier).addProduct(product),
        onLongPress: () => ProductDetailDialog.show(context, product),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
                color: isLow
                    ? AppTheme.warning.withValues(alpha: 0.4)
                    : AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 1. Image
              GestureDetector(
                onTap: () => ProductDetailDialog.show(context, product),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ProductImage(imagePath: product.imagePath),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. Product Name & Info
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.barcode != null)
                      Text(product.barcode!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Stock Info
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STOK', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    Text(
                      '${Formatters.decimal(product.stock)} ${product.baseUnit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isLow ? AppTheme.warning : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Sell Prices
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('HARGA JUAL', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    Text(
                      Formatters.currency(product.basePrice),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.accent),
                    ),
                    if (product.units.isNotEmpty)
                      Text('+${product.units.length} Satuan', style: const TextStyle(fontSize: 9, color: AppTheme.accent)),
                  ],
                ),
              ),

              const SizedBox(width: 16),
              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
