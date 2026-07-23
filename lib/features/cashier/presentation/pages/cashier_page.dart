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
import '../../providers/barcode_event_provider.dart';
import '../widgets/payment_dialog.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 800;
    final cart = ref.watch(cartProvider);

    // Global barcode listener logic remains same
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      _searchCtrl.text = next.barcode;
      _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: next.barcode.length));
      ref.read(productSearchQueryProvider.notifier).set(next.barcode);
    });

    return BarcodeListener(
      autoAdd: true,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Row(
          children: [
            // Left: Product Selection
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  PageHeader(
                    title: 'Kasir',
                    icon: Icons.point_of_sale_rounded,
                    actions: [
                      if (!isMobile)
                        Text(Formatters.date(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  
                  // Search Area
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: AppTheme.surface,
                    child: AppSearchField(
                      controller: _searchCtrl,
                      hintText: 'Cari produk...',
                      onChanged: (v) => ref.read(productSearchQueryProvider.notifier).set(v),
                    ),
                  ),

                  // Categories
                  _CategoryFilter(
                    selected: category,
                    onSelected: (c) => ref.read(productCategoryFilterProvider.notifier).set(c),
                  ),

                  // Product Selection Area
                  Expanded(
                    child: SafeArea(
                      top: false,
                      child: isMobile 
                        ? const _ProductGrid(isCompact: true) 
                        : const _ProductGrid(isCompact: false),
                    ),
                  ),
                ],
              ),
            ),

            // Right: Cart Panel (Desktop only)
            if (!isMobile)
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(left: BorderSide(color: AppTheme.border)),
                ),
                child: const _CartPanel(),
              ),
          ],
        ),
        
        // Mobile Cart Summary
        bottomNavigationBar: isMobile && !cart.isEmpty
          ? _MobileCartSummary(cart: cart)
          : null,
      ),
    );
  }
}

class _MobileCartSummary extends StatelessWidget {
  final CartState cart;
  const _MobileCartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cart.itemCount} Item', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  Text(Formatters.currency(cart.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showMobileCart(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 50),
                backgroundColor: AppTheme.primary,
              ),
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => const _CartPanel(),
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
    final categories = productsAsync.asData?.value.map((p) => p.category).toSet().toList() ?? [];

    return Container(
      height: 56,
      color: AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _CategoryChip(label: 'Semua', selected: selected == null, onTap: () => onSelected(null)),
          ...categories.map((c) => _CategoryChip(label: c, selected: selected == c, onTap: () => onSelected(c))),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

// ── Product Grid ───────────────────────────────────────────────────────────

class _ProductGrid extends ConsumerWidget {
  final bool isCompact;
  const _ProductGrid({required this.isCompact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(filteredProductsProvider);
    final productsAsync = ref.watch(productsProvider);

    if (products.isEmpty) {
      if (productsAsync.isLoading) return const AppLoading();
      return const EmptyState(icon: Icons.search_off_rounded, title: 'Produk tidak ditemukan');
    }

    if (isCompact) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => _ProductGridTile(product: products[i]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, i) => _ProductListTile(product: products[i]),
    );
  }
}

class _ProductGridTile extends ConsumerWidget {
  final Product product;
  const _ProductGridTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ProductImage(imagePath: product.imagePath),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(Formatters.currency(product.basePrice), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Stok: ${Formatters.decimal(product.stock)}', style: TextStyle(fontSize: 10, color: product.isLowStock ? AppTheme.danger : AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  final Product product;
  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
      child: Row(
        children: [
          ProductImage(imagePath: product.imagePath, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(product.category, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Formatters.currency(product.basePrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            Text('Stok: ${Formatters.decimal(product.stock)}', style: const TextStyle(fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

// ── Cart Panel ─────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel();

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _discountCtrl;
  late final FocusNode _discountFocus;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _discountCtrl = TextEditingController(text: cart.transDiscountValue == 0 ? '' : cart.transDiscountValue.toStringAsFixed(0));
    _discountFocus = FocusNode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _discountCtrl.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(children: [
      // Mobile Close Handle or Title
      if (isMobile)
        Container(
          height: 5, width: 40,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5)),
        ),

      // Header
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.shopping_cart_rounded, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: const Text('Hapus Semua', style: TextStyle(color: AppTheme.danger)),
            ),
        ]),
      ),

      // Cart items
      Expanded(
        child: cart.isEmpty
            ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Keranjang kosong')
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CartItemTile(item: cart.items[i]),
              ),
      ),

      // Totals
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(children: [
          _totalRow('Subtotal', cart.grossSubtotal),
          if (cart.itemDiscountTotal > 0)
            _totalRow('Diskon Item', -cart.itemDiscountTotal, color: AppTheme.success),
          const Divider(height: 24),
          Row(children: [
            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text(Formatters.currency(cart.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primary)),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: cart.isEmpty ? null : () => PaymentDialog.show(context),
            child: const Text('PROSES PEMBAYARAN'),
          ),
        ]),
      ),
    ]);
  }

  Widget _totalRow(String label, double val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Text(Formatters.currency(val), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${Formatters.currency(item.soldPrice)} x ${Formatters.decimal(item.quantity)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          _qtyControl(ref),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref.read(cartProvider.notifier).removeItem(item.id),
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _qtyControl(WidgetRef ref) {
    return Row(
      children: [
        _qtyBtn(Icons.remove, () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1)),
        const SizedBox(width: 12),
        Text(Formatters.decimal(item.quantity), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        _qtyBtn(Icons.add, () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1)),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
