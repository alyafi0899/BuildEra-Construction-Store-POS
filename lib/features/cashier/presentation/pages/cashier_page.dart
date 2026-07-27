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
import '../../../../shared/widgets/security_gate.dart';

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

    // Listen to global barcode events to update the local search field
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      
      if (next.wasFocused) {
        _searchCtrl.text = next.barcode;
        _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: next.barcode.length),
        );
        ref.read(productSearchQueryProvider.notifier).set(next.barcode);
        return;
      }

      _searchCtrl.text = next.barcode;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: next.barcode.length),
      );
      ref.read(productSearchQueryProvider.notifier).set(next.barcode);
    });

    return BarcodeListener(
      autoAdd: true,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: PinGate(
          child: Row(
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
                        onClear: () {
                          _searchCtrl.clear();
                          ref.read(productSearchQueryProvider.notifier).set('');
                        },
                      ),
                    ),

                    // Categories
                    _CategoryFilter(
                      selected: category,
                      onSelected: (c) => ref.read(productCategoryFilterProvider.notifier).set(c),
                    ),

                    // Product Selection Area
                    const Expanded(
                      child: _ProductGrid(),
                    ),
                  ],
                ),
              ),

              // Right: Cart Panel (Only show on desktop/tablet)
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
        ),
        // Floating Cart Button for Mobile
        floatingActionButton: isMobile ? FloatingActionButton.extended(
          onPressed: () => _showMobileCart(context),
          label: Consumer(builder: (context, ref, child) {
            final cart = ref.watch(cartProvider);
            return Text('Keranjang (${cart.itemCount})');
          }),
          icon: const Icon(Icons.shopping_cart_rounded),
          backgroundColor: AppTheme.accent,
        ) : null,
      ),
    );
  }

  void _showMobileCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const Scaffold(
        body: _CartPanel(),
      ),
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
      height: 54,
      color: AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _Chip(
            label: 'Semua',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map((c) => _Chip(
            label: c,
            selected: selected == c,
            onTap: () => onSelected(c),
          )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.accent.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.accent,
        labelStyle: TextStyle(
          color: selected ? AppTheme.accent : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ProductListTile(
          key: ValueKey('cashier_prod_${products[i].id}'),
          product: products[i],
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
    
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
      child: InkWell(
        onLongPress: () => ProductDetailDialog.show(context, product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImage(imagePath: product.imagePath, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${Formatters.decimal(product.stock)} ${product.baseUnit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLow ? AppTheme.danger : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(product.basePrice),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.accent),
                  ),
                  if (product.units.isNotEmpty)
                    Text('+${product.units.length} Satuan', style: const TextStyle(fontSize: 9, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accent, size: 20),
            ],
          ),
        ),
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
    _discountCtrl = TextEditingController(
        text: cart.transDiscountValue == 0 ? '' : cart.transDiscountValue.toStringAsFixed(0));
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

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          const Icon(Icons.shopping_cart_rounded, color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          if (!cart.isEmpty)
            IconButton(
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title: 'Kosongkan',
                    content: 'Hapus semua item?',
                    confirmLabel: 'Hapus',
                    confirmColor: AppTheme.danger);
                if (ok) ref.read(cartProvider.notifier).clear();
              },
              icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppTheme.danger),
            ),
        ]),
      ),

      // Cart items
      Expanded(
        child: cart.isEmpty
            ? const EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Kosong',
              )
            : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CartItemTile(item: cart.items[i]),
                ),
      ),

      // Totals
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceAlt,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(children: [
          _TotalRow(label: 'Total', value: cart.total, isMain: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: cart.isEmpty ? null : () => PaymentDialog.show(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
              child: const Text('BAYAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isMain;
  const _TotalRow({required this.label, required this.value, this.isMain = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: TextStyle(color: isMain ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
      const Spacer(),
      Text(Formatters.currency(value), style: TextStyle(
        color: isMain ? AppTheme.accent : AppTheme.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: isMain ? 18 : 14,
      )),
    ]);
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
          IconButton(
            onPressed: () => notifier.removeItem(item.id),
            icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ]),
        Row(children: [
          Text('${Formatters.decimal(item.quantity)} ${item.selectedUnit.unitName}', style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
          const Spacer(),
          Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ]),
    );
  }
}
