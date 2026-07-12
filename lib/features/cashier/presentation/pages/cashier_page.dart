import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../products/providers/product_provider.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/scan_mode_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../widgets/payment_dialog.dart';

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
    final autoAdd = ref.watch(scanModeProvider);
    final category = ref.watch(productCategoryFilterProvider);

    // Listen to global barcode events to update the local search field
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      
      // Only react if NOT in auto-add mode, to show search results
      if (!autoAdd) {
        _searchCtrl.text = next.barcode;
        _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: next.barcode.length),
        );
        ref.read(productSearchQueryProvider.notifier).set(next.barcode);
      } else {
        // If auto-add, clear search field after a successful scan
        if (next.product != null) {
          _searchCtrl.clear();
          ref.read(productSearchQueryProvider.notifier).set('');
        }
      }
    });

    return Row(children: [
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
              // Scan Mode Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: autoAdd
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: autoAdd ? AppTheme.accent : AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(autoAdd ? Icons.bolt_rounded : Icons.search_rounded,
                        size: 16,
                        color: autoAdd ? AppTheme.accent : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(autoAdd ? 'Jual Langsung' : 'Cari Produk',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: autoAdd
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: autoAdd,
                      onChanged: (v) =>
                          ref.read(scanModeProvider.notifier).setEnabled(v),
                      activeTrackColor: AppTheme.accent,
                    ),
                  ],
                ),
              ),
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
              onSubmitted: (_) {
                final cart = ref.read(cartProvider);
                if (!cart.isEmpty) PaymentDialog.show(context);
              },
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
        child: const _CartPanel(),
      ),
    ]);
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

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) =>
                cart.isEmpty ? null : PaymentDialog.show(context),
          ),
        },
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: AppTheme.accent, size: 20),
              const SizedBox(width: 10),
              Text('Keranjang', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              if (cart.itemCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${cart.itemCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showConfirmDialog(context,
                        title: 'Kosongkan Keranjang',
                        content: 'Yakin kosongkan semua item?',
                        confirmLabel: 'Kosongkan',
                        confirmColor: AppTheme.warning);
                    if (ok) ref.read(cartProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Hapus Semua'),
                ),
            ]),
          ),

          // Cart items
          Expanded(
            child: cart.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Keranjang kosong',
                    subtitle: 'Pilih produk untuk ditambahkan',
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = cart.items[i];
                        return _CartItemTile(
                          key: ValueKey('cart_item_${item.id}'), // Use stable key
                          item: item,
                        );
                      },
                    ),
                  ),
          ),

          // Totals & checkout
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(children: [
              // Customer Name (Optional)
              TextField(
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Nama Pelanggan (Opsional)',
                  isDense: true,
                  prefixIcon: Icon(Icons.person_outline, size: 16),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => ref
                    .read(cartProvider.notifier)
                    .setCustomer(null, v.isEmpty ? null : v),
                onSubmitted: (_) =>
                    cart.isEmpty ? null : PaymentDialog.show(context),
              ),
              const SizedBox(height: 12),

              // Subtotal
              _TotalRow(label: 'Subtotal', value: cart.grossSubtotal),

              // Item Discounts
              if (cart.itemDiscountTotal > 0)
                _TotalRow(
                    label: 'Potongan Item',
                    value: -cart.itemDiscountTotal,
                    valueColor: AppTheme.success),

              const SizedBox(height: 8),

              // Transaction Discount
              Row(children: [
                const Text('Diskon Transaksi',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                SizedBox(
                  width: 50,
                  child: DropdownButton<DiscountType>(
                    value: cart.transDiscountType,
                    isDense: true,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                    items: const [
                      DropdownMenuItem(
                          value: DiscountType.fixed, child: Text('Rp')),
                      DropdownMenuItem(
                          value: DiscountType.percentage, child: Text('%')),
                    ],
                    onChanged: (v) => ref
                        .read(cartProvider.notifier)
                        .setTransDiscount(cart.transDiscountValue, v!),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _discountCtrl,
                    focusNode: _discountFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onChanged: (v) => ref
                        .read(cartProvider.notifier)
                        .setTransDiscount(
                            double.tryParse(v) ?? 0, cart.transDiscountType),
                    onSubmitted: (_) =>
                        cart.isEmpty ? null : PaymentDialog.show(context),
                  ),
                ),
              ]),

              const SizedBox(height: 8),

              // PPN
              Row(children: [
                const Text('PPN (11%)',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                Switch.adaptive(
                  value: cart.taxEnabled,
                  onChanged: (_) => ref.read(cartProvider.notifier).toggleTax(),
                  activeTrackColor: AppTheme.accent,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    Formatters.currency(cart.taxAmount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ]),

              const Divider(height: 24, color: AppTheme.border),

              const Divider(height: 24, color: AppTheme.border),

              Row(children: [
                Text('TOTAL',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18)),
                const Spacer(),
                Text(Formatters.currency(cart.total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.accent,
                          fontSize: 24,
                        )),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      cart.isEmpty ? null : () => PaymentDialog.show(context),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('BAYAR SEKARANG'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? valueColor;
  const _TotalRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(Formatters.currency(value),
            style: TextStyle(
                color: valueColor ?? AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Cart Item Tile ─────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartItemTile({super.key, required this.item});

  @override
  ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  late TextEditingController _qtyCtrl;
  late FocusNode _qtyFocus; // New

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _qtyFocus = FocusNode(); // New
  }

  @override
  void didUpdateWidget(_CartItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.quantity != widget.item.quantity) {
      // Avoid resetting cursor if this field has focus
      if (!_qtyFocus.hasFocus) {
        _qtyCtrl.text = widget.item.quantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _qtyFocus.dispose(); // New
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.product.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          IconButton(
            onPressed: () => _showItemEditDialog(context, ref, item),
            icon: const Icon(Icons.edit_note_rounded,
                size: 18, color: AppTheme.accent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => notifier.removeItem(item.id),
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          // Unit selector
          if (item.product.allUnits.length > 1)
            SizedBox(
              width: 80,
              child: DropdownButton<String>(
                value: item.selectedUnit.unitName,
                isDense: true,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.surfaceAlt,
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                items: item.product.allUnits
                    .map((u) => DropdownMenuItem(
                          value: u.unitName,
                          child: Text(u.unitName, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  final u =
                      item.product.allUnits.firstWhere((u) => u.unitName == v);
                  notifier.updateUnit(item.id, u);
                },
              ),
            )
          else
            Text(item.selectedUnit.unitName,
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          const Spacer(),
          // Qty controls
          _QtyButton(
              icon: Icons.remove,
              onTap: () {
                final q = item.quantity - 1;
                notifier.updateQuantity(item.id, q);
                _qtyCtrl.text = q <= 0 ? '0' : q.toString();
              }),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _qtyCtrl,
              focusNode: _qtyFocus, // Use the FocusNode
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                final qty = double.tryParse(v) ?? 0;
                if (qty > 0) {
                  notifier.updateQuantity(item.id, qty);
                }
              },
              onSubmitted: (v) =>
                  notifier.updateQuantity(item.id, double.tryParse(v) ?? 1),
            ),
          ),
          _QtyButton(
              icon: Icons.add,
              onTap: () {
                final q = item.quantity + 1;
                notifier.updateQuantity(item.id, q);
                _qtyCtrl.text = q.toString();
              }),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.isOverridden)
                Text(Formatters.currency(item.originalPrice),
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough)),
              Text(Formatters.currency(item.soldPrice),
                  style: TextStyle(
                    color: item.isOverridden
                        ? AppTheme.warning
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        item.isOverridden ? FontWeight.w600 : FontWeight.w400,
                  )),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.totalDiscount > 0)
                Text('-${Formatters.currency(item.totalDiscount)}',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              Text(Formatters.currency(item.subtotal),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ]),
      ]),
    );
  }

  void _showItemEditDialog(BuildContext context, WidgetRef ref, CartItem item) {
    showDialog(
      context: context,
      builder: (context) => _ItemEditDialog(item: item),
    );
  }
}

class _ItemEditDialog extends ConsumerStatefulWidget {
  final CartItem item;
  const _ItemEditDialog({required this.item});

  @override
  ConsumerState<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends ConsumerState<_ItemEditDialog> {
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late DiscountType _discountType;

  @override
  void initState() {
    super.initState();
    _priceCtrl =
        TextEditingController(text: widget.item.soldPrice.toStringAsFixed(0));
    _discountCtrl = TextEditingController(
        text: widget.item.discountValue.toStringAsFixed(0));
    _discountType = widget.item.discountType;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(cartProvider.notifier);

    return AlertDialog(
      title:
          Text(widget.item.product.name, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga Jual (Override)',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Potongan Harga',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<DiscountType>(
                    initialValue: _discountType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tipe', isDense: true),
                    items: [
                      DropdownMenuItem(
                          value: DiscountType.fixed, child: Text('Rp')),
                      DropdownMenuItem(
                          value: DiscountType.percentage, child: Text('%')),
                    ],
                    onChanged: (v) => setState(() => _discountType = v!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            final price =
                double.tryParse(_priceCtrl.text) ?? widget.item.soldPrice;
            final disc = double.tryParse(_discountCtrl.text) ?? 0;

            if (price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Harga harus lebih dari 0')));
              return;
            }

            notifier.updateSoldPrice(widget.item.id, price);
            notifier.setItemDiscount(widget.item.id, disc, _discountType);
            Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
