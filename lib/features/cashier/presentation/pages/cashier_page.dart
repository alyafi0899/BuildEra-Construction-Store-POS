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
import '../../providers/scan_mode_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../widgets/payment_dialog.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoAdd = ref.watch(scanModeProvider);

    // Listen to global barcode events to update the local search field
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      
      // Only react if NOT in auto-add mode, to show search results
      if (!autoAdd) {
        setState(() {
          _search = next.barcode;
          _searchCtrl.text = next.barcode;
          _searchCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: next.barcode.length),
          );
        });
      } else {
        // If auto-add, clear search field after a successful scan
        if (next.product != null) {
          setState(() {
            _search = '';
            _searchCtrl.clear();
          });
        }
      }
    });

    return Row(children: [
      // ── Left: Product Search & Grid ──────────────────────────────────
      Expanded(
        flex: 6,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.surface,
            child: Column(children: [
              Row(children: [
                const Icon(Icons.point_of_sale_rounded,
                    color: AppTheme.accent, size: 22),
                const SizedBox(width: 10),
                Text('Kasir',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                // Scan Mode Toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: autoAdd
                        ? AppTheme.accent.withValues(alpha: 0.1)
                        : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: autoAdd ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Row(children: [
                    Icon(
                        autoAdd ? Icons.bolt_rounded : Icons.search_rounded,
                        size: 16,
                        color: autoAdd
                            ? AppTheme.accent
                            : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(autoAdd ? 'Jual Langsung' : 'Cari Produk',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: autoAdd
                                ? AppTheme.accent
                                : AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: autoAdd,
                      onChanged: (v) =>
                          ref.read(scanModeProvider.notifier).setEnabled(v),
                      activeTrackColor: AppTheme.accent,
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Text(Formatters.date(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Cari produk atau scan barcode...',
                    onChanged: (v) => setState(() => _search = v),
                    onClear: () => setState(() {
                      _search = '';
                      _searchCtrl.clear();
                    }),
                  ),
                ),
              ]),
            ]),
          ),

          // Category filter chips
          _CategoryFilter(
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),

          // Product grid
          Expanded(
              child: _ProductGrid(search: _search, category: _category)),
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
  final String search;
  final String? category;
  const _ProductGrid({required this.search, this.category});

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
    return ref.watch(productsProvider).when(
          loading: () => const AppLoading(),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (products) {
            final filtered = products.where((p) {
              final q = widget.search.toLowerCase();
              final matchSearch = q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  (p.barcode?.contains(q) ?? false);
              final matchCat =
                  widget.category == null || p.category == widget.category;
              return matchSearch && matchCat;
            }).toList();

            if (filtered.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Produk tidak ditemukan',
              );
            }

            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 180,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ProductCard(product: filtered[i]),
              ),
            );
          },
        );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.isLowStock;
    return GestureDetector(
      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isLow
                  ? AppTheme.warning.withValues(alpha: 0.4)
                  : AppTheme.border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(cartProvider.notifier).addProduct(product),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ProductImage(imagePath: product.imagePath),
                    const Spacer(),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.warning, size: 12),
                      ),
                  ]),
                  const Spacer(),
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    product.units.isNotEmpty
                        ? Formatters.currency(product.units.first.sellPrice)
                        : Formatters.currency(product.basePrice),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${Formatters.decimal(product.stock)} ${product.baseUnit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLow ? AppTheme.warning : null,
                        ),
                  ),
                ],
              ),
            ),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Column(children: [
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  itemBuilder: (_, i) => _CartItemTile(item: cart.items[i]),
                ),
              ),
      ),

      // Totals & checkout
      // ...

      // Totals & checkout
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
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
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const Spacer(),
            DropdownButton<DiscountType>(
              value: cart.transDiscountType,
              isDense: true,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: AppTheme.accent),
              items: [
                DropdownMenuItem(value: DiscountType.fixed, child: Text('Rp')),
                DropdownMenuItem(
                    value: DiscountType.percentage, child: Text('%')),
              ],
              onChanged: (v) => ref
                  .read(cartProvider.notifier)
                  .setTransDiscount(cart.transDiscountValue, v!),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
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
              ),
            ),
          ]),

          const SizedBox(height: 8),

          // PPN
          Row(children: [
            const Text('PPN (11%)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
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
  const _CartItemTile({required this.item});

  @override
  ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void didUpdateWidget(_CartItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
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
                overflow: TextOverflow.ellipsis),
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
            DropdownButton<String>(
              value: item.selectedUnit.unitName,
              isDense: true,
              underline: const SizedBox(),
              dropdownColor: AppTheme.surfaceAlt,
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              items: item.product.allUnits
                  .map((u) => DropdownMenuItem(
                        value: u.unitName,
                        child: Text(u.unitName),
                      ))
                  .toList(),
              onChanged: (v) {
                final u =
                    item.product.allUnits.firstWhere((u) => u.unitName == v);
                notifier.updateUnit(item.id, u);
              },
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
                child: DropdownButtonFormField<DiscountType>(
                  initialValue: _discountType,
                  decoration: const InputDecoration(labelText: 'Tipe'),
                  items: [
                    DropdownMenuItem(
                        value: DiscountType.fixed, child: Text('Rp')),
                    DropdownMenuItem(
                        value: DiscountType.percentage, child: Text('%')),
                  ],
                  onChanged: (v) => setState(() => _discountType = v!),
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
