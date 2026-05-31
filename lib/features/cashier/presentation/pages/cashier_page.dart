import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
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
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(children: [
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
                  const Icon(Icons.point_of_sale_rounded, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Kasir', style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  Text(Formatters.date(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: AppSearchField(
                      controller: _searchCtrl,
                      hintText:   'Cari produk atau scan barcode...',
                      onChanged:  (v) => setState(() => _search = v),
                      onClear:    () => setState(() { _search = ''; _searchCtrl.clear(); }),
                    ),
                  ),
                ]),
              ]),
            ),

            // Category filter chips
            _CategoryFilter(
              selected:   _category,
              onSelected: (c) => setState(() => _category = c),
            ),

            // Product grid
            Expanded(child: _ProductGrid(search: _search, category: _category)),
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
    final categories    = productsAsync.asData?.value.map((p) => p.category).toSet().toList() ?? [];

    return Container(
      height: 48,
      color:  AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _Chip(label: 'Semua', selected: selected == null, onTap: () => onSelected(null)),
          ...categories.map((c) => _Chip(label: c, selected: selected == c, onTap: () => onSelected(c))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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
            color:        selected ? AppTheme.accent : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:      selected ? Colors.white : AppTheme.textSecondary,
              fontSize:   12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product Grid ───────────────────────────────────────────────────────────

class _ProductGrid extends ConsumerWidget {
  final String  search;
  final String? category;
  const _ProductGrid({required this.search, this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(productsProvider).when(
      loading: () => const AppLoading(),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        final filtered = products.where((p) {
          final q = search.toLowerCase();
          final matchSearch = q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.contains(q) ?? false);
          final matchCat = category == null || p.category == category;
          return matchSearch && matchCat;
        }).toList();

        if (filtered.isEmpty) {
          return const EmptyState(
            icon:  Icons.search_off_rounded,
            title: 'Produk tidak ditemukan',
          );
        }

        return GridView.builder(
          padding:     const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisExtent:     180,
            crossAxisSpacing:   12,
            mainAxisSpacing:    12,
          ),
          itemCount:   filtered.length,
          itemBuilder: (_, i) => _ProductCard(product: filtered[i]),
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
          color:        AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: isLow ? AppTheme.warning.withValues(alpha: 0.4) : AppTheme.border),
        ),
        child: Material(
          color:        Colors.transparent,
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
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color:        AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: AppTheme.accent, size: 22),
                    ),
                    const Spacer(),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 12),
                      ),
                  ]),
                  const Spacer(),
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    product.units.isNotEmpty
                        ? Formatters.currency(product.units.first.sellPrice)
                        : Formatters.currency(product.basePrice),
                    style: const TextStyle(
                      color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700,
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

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          const Icon(Icons.shopping_cart_rounded, color: AppTheme.accent, size: 20),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          if (!cart.isEmpty)
            TextButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title:        'Kosongkan Keranjang',
                    content:      'Yakin kosongkan semua item?',
                    confirmLabel: 'Kosongkan',
                    confirmColor: AppTheme.warning);
                if (ok) ref.read(cartProvider.notifier).clear();
              },
              icon:  const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Hapus Semua'),
            ),
        ]),
      ),

      // Cart items
      Expanded(
        child: cart.isEmpty
            ? const EmptyState(
                icon:     Icons.shopping_cart_outlined,
                title:    'Keranjang kosong',
                subtitle: 'Pilih produk untuk ditambahkan',
              )
            : ListView.separated(
                padding:  const EdgeInsets.all(16),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder:      (_, i) => _CartItemTile(item: cart.items[i]),
              ),
      ),

      // Totals & checkout
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(children: [
          // Discount toggle
          Row(children: [
            Text('Subtotal', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(Formatters.currency(cart.subtotal), style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          // Diskon
          Row(children: [
            Text('Diskon', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            SizedBox(
              width: 110,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign:    TextAlign.right,
                style:        const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration:   const InputDecoration(
                  prefixText:       'Rp ',
                  isDense:          true,
                  contentPadding:   EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (v) => ref.read(cartProvider.notifier).setDiscount(double.tryParse(v) ?? 0),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('PPN (11%)', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Switch.adaptive(
              value:     cart.taxEnabled,
              onChanged: (_) => ref.read(cartProvider.notifier).toggleTax(),
              activeColor: AppTheme.accent,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: Text(
                Formatters.currency(cart.taxAmount),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ]),
          const Divider(height: 20, color: AppTheme.border),
          Row(children: [
            Text('TOTAL', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            const Spacer(),
            Text(Formatters.currency(cart.total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.accent, fontSize: 22,
                    )),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: cart.isEmpty ? null : () => PaymentDialog.show(context),
              icon:  const Icon(Icons.payment_rounded),
              label: const Text('Proses Pembayaran'),
              style: ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]);
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
  void dispose() { _qtyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item   = widget.item;
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.product.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            onPressed: () => notifier.removeItem(item.id),
            icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          // Unit selector
          if (item.product.units.length > 1)
            DropdownButton<String>(
              value:     item.selectedUnit.unitName,
              isDense:   true,
              underline: const SizedBox(),
              dropdownColor: AppTheme.surfaceAlt,
              style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
              items: item.product.units.map((u) => DropdownMenuItem(
                value: u.unitName,
                child: Text(u.unitName),
              )).toList(),
              onChanged: (v) {
                final u = item.product.units.firstWhere((u) => u.unitName == v);
                notifier.updateUnit(item.id, u);
              },
            )
          else
            Text(item.selectedUnit.unitName,
                style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          // Qty controls
          _QtyButton(icon: Icons.remove, onTap: () {
            final q = item.quantity - 1;
            notifier.updateQuantity(item.id, q);
            _qtyCtrl.text = q <= 0 ? '0' : q.toString();
          }),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _qtyCtrl,
              textAlign:  TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense:        true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border:         InputBorder.none,
              ),
              onSubmitted: (v) => notifier.updateQuantity(item.id, double.tryParse(v) ?? 1),
            ),
          ),
          _QtyButton(icon: Icons.add, onTap: () {
            final q = item.quantity + 1;
            notifier.updateQuantity(item.id, q);
            _qtyCtrl.text = q.toString();
          }),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text(Formatters.currency(item.selectedUnit.sellPrice),
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(Formatters.currency(item.subtotal),
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color:        AppTheme.border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
