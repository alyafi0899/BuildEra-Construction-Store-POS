// lib/features/cashier/presentation/pages/cashier_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../payment/presentation/pages/payment_dialog.dart';
import '../../domain/entities/cart_entity.dart';
import '../providers/cart_provider.dart';

class CashierPage extends ConsumerWidget {
  const CashierPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(children: [
      Expanded(flex: 3, child: _ProductPanel()),
      const VerticalDivider(width: 1, color: AppColors.border),
      SizedBox(width: 380, child: _CartPanel()),
    ]);
  }
}

// ─── PRODUCT PANEL ────────────────────────────────────────────────────────────

class _ProductPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProductPanel> createState() => _ProductPanelState();
}

class _ProductPanelState extends ConsumerState<_ProductPanel> {
  final _searchCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(allProductsProvider);
    final query = ref.watch(cashierSearchQueryProvider);

    return Column(children: [
      // Search bar
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          Row(children: [
            Text('Kasir', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
              child: Text(AppFormatters.formatDateTime(DateTime.now()),
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SearchField(
                controller: _searchCtrl,
                hintText: 'Cari produk berdasarkan nama...',
                onChanged: (v) { ref.read(cashierSearchQueryProvider.notifier).state = v; setState(() {}); },
                onClear: () { ref.read(cashierSearchQueryProvider.notifier).state = ''; setState(() {}); },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _barcodeCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Scan barcode...',
                  prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.textSecondary, size: 18),
                ),
                onSubmitted: (v) => _onBarcode(v, products),
              ),
            ),
          ]),
        ]),
      ),

      // Category filter
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ['Semua', ...{...products.map((p) => p.category)}].length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cats = ['Semua', ...{...products.map((p) => p.category)}];
            final cat = cats[index];
            final isSelected = (_selectedCategory == null && cat == 'Semua') || _selectedCategory == cat;
            return Center(
              child: FilterChip(
                label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat == 'Semua' ? null : cat),
                backgroundColor: AppColors.surfaceVariant,
                selectedColor: AppColors.primaryContainer,
                checkmarkColor: AppColors.primary,
                side: BorderSide(color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
      ),

      // Product grid
      Expanded(
        child: Builder(builder: (_) {
          var filtered = products.where((p) => p.stockQuantity > 0).toList();
          if (query.isNotEmpty) {
            final q = query.toLowerCase();
            filtered = filtered.where((p) =>
                p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false)).toList();
          }
          if (_selectedCategory != null) {
            filtered = filtered.where((p) => p.category == _selectedCategory).toList();
          }

          if (filtered.isEmpty) {
            return const EmptyState(icon: Icons.search_off_rounded, title: 'Produk tidak ditemukan');
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 1.4, crossAxisSpacing: 10, mainAxisSpacing: 10,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _ProductCard(product: filtered[i])
                .animate(delay: Duration(milliseconds: 20 * i))
                .fadeIn(duration: 200.ms).scale(begin: const Offset(0.95, 0.95)),
          );
        }),
      ),
    ]);
  }

  void _onBarcode(String barcode, List<ProductEntity> products) {
    if (barcode.isEmpty) return;
    _barcodeCtrl.clear();
    try {
      final product = products.firstWhere((p) => p.barcode == barcode);
      _showAddDialog(product);
    } catch (_) {
      showErrorSnackbar(context, 'Produk dengan barcode "$barcode" tidak ditemukan');
    }
  }

  void _showAddDialog(ProductEntity product) {
    showDialog(context: context, builder: (_) => _AddToCartDialog(product: product));
  }
}

// ─── PRODUCT CARD ─────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerStatefulWidget {
  final ProductEntity product;
  const _ProductCard({required this.product});
  @override ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showDialog(context: context, builder: (_) => _AddToCartDialog(product: p)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hov ? AppColors.surfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hov ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
            boxShadow: _hov ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 12)] : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.construction_rounded, color: AppColors.primary, size: 16),
              ),
              const Spacer(),
              if (p.isLowStock) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 8),
            Text(p.name,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(
              p.units.isNotEmpty ? AppFormatters.formatCurrency(p.units.first.sellingPrice) : AppFormatters.formatCurrency(p.basePrice),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text('Stok: ${AppFormatters.formatQuantity(p.stockQuantity)} ${p.baseUnit}',
                style: TextStyle(color: p.isLowStock ? AppColors.warning : AppColors.textSecondary, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ─── ADD TO CART DIALOG ───────────────────────────────────────────────────────

class _AddToCartDialog extends ConsumerStatefulWidget {
  final ProductEntity product;
  const _AddToCartDialog({required this.product});
  @override ConsumerState<_AddToCartDialog> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends ConsumerState<_AddToCartDialog> {
  late ProductUnitEntity _selectedUnit;
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.product.units.isNotEmpty
        ? widget.product.units.first
        : ProductUnitEntity(productId: widget.product.id ?? 0, unitName: widget.product.baseUnit, conversionRatio: 1, sellingPrice: widget.product.basePrice, isBaseUnit: true);
  }

  @override
  void dispose() { _qtyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final subtotal = qty * _selectedUnit.sellingPrice;

    return AlertDialog(
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 2)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Unit selector
          DropdownButtonFormField<ProductUnitEntity>(
            value: _selectedUnit,
            decoration: const InputDecoration(labelText: 'Satuan'),
            dropdownColor: AppColors.surfaceVariant,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            items: p.units.map((u) => DropdownMenuItem(
              value: u,
              child: Row(children: [
                Text(u.unitName),
                const SizedBox(width: 8),
                Text(AppFormatters.formatCurrency(u.sellingPrice), style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                if (!u.isBaseUnit) ...[
                  const SizedBox(width: 4),
                  Text('= ${u.conversionRatio} ${p.baseUnit}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ]),
            )).toList(),
            onChanged: (u) => setState(() => _selectedUnit = u!),
          ),
          const SizedBox(height: 16),

          // Qty control
          Row(children: [
            IconButton(
              onPressed: () {
                final cur = double.tryParse(_qtyCtrl.text) ?? 1;
                if (cur > 1) { _qtyCtrl.text = (cur - 1).toString(); setState(() {}); }
              },
              icon: const Icon(Icons.remove_circle_rounded, color: AppColors.primary),
            ),
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
                decoration: InputDecoration(suffixText: _selectedUnit.unitName, suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              onPressed: () { final cur = double.tryParse(_qtyCtrl.text) ?? 1; _qtyCtrl.text = (cur + 1).toString(); setState(() {}); },
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
            ),
          ]),
          const SizedBox(height: 16),

          // Stock info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Stok tersedia', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('${AppFormatters.formatQuantity(p.stockQuantity)} ${p.baseUnit}',
                  style: TextStyle(color: p.isLowStock ? AppColors.warning : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),

          // Subtotal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subtotal', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(AppFormatters.formatCurrency(subtotal),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton.icon(
          onPressed: () {
            final qty = double.tryParse(_qtyCtrl.text) ?? 0;
            if (qty <= 0) { showErrorSnackbar(context, 'Jumlah harus lebih dari 0'); return; }
            final stockNeeded = qty * _selectedUnit.conversionRatio;
            if (stockNeeded > widget.product.stockQuantity) {
              showErrorSnackbar(context, 'Stok tidak cukup. Tersedia: ${AppFormatters.formatQuantity(widget.product.stockQuantity)} ${widget.product.baseUnit}');
              return;
            }
            ref.read(cartProvider.notifier).addItem(widget.product, _selectedUnit, qty);
            Navigator.pop(context);
            showSuccessSnackbar(context, '${widget.product.name} ditambahkan ke keranjang');
          },
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
          label: const Text('Tambah ke Keranjang'),
        ),
      ],
    );
  }
}

// ─── CART PANEL ───────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      color: AppColors.surface,
      child: Column(children: [
        // Cart header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Keranjang', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (cart.itemCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            const Spacer(),
            if (!cart.isEmpty)
              TextButton.icon(
                onPressed: () async {
                  final ok = await showConfirmDialog(context, title: 'Kosongkan Keranjang', message: 'Hapus semua item?', confirmLabel: 'Kosongkan');
                  if (ok) ref.read(cartProvider.notifier).clearCart();
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                label: const Text('Kosongkan', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
          ]),
        ),

        // Items
        Expanded(
          child: cart.isEmpty
              ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Keranjang kosong', subtitle: 'Klik produk untuk menambahkan')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, i) => _CartItemTile(item: cart.items[i], index: i),
                ),
        ),

        if (!cart.isEmpty) ...[
          const Divider(height: 1, color: AppColors.border),
          _CartSummary(cart: cart),
        ],
      ]),
    );
  }
}

class _CartItemTile extends ConsumerStatefulWidget {
  final CartItemEntity item;
  final int index;
  const _CartItemTile({required this.item, required this.index});
  @override ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: AppFormatters.formatQuantity(widget.item.quantity));
  }

  @override
  void didUpdateWidget(_CartItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.quantity != widget.item.quantity) {
      _qtyCtrl.text = AppFormatters.formatQuantity(widget.item.quantity);
    }
  }

  @override
  void dispose() { _qtyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.productName,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            onPressed: () => ref.read(cartProvider.notifier).removeItem(widget.index),
            icon: const Icon(Icons.close_rounded, size: 14),
            color: AppColors.textDisabled, visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          // Qty stepper
          Container(
            height: 30,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _qBtn(Icons.remove, () {
                final cur = double.tryParse(_qtyCtrl.text) ?? 1;
                if (cur > 0.1) {
                  final n = cur - 1;
                  _qtyCtrl.text = AppFormatters.formatQuantity(n);
                  ref.read(cartProvider.notifier).updateItemQuantity(widget.index, n);
                }
              }),
              SizedBox(
                width: 46,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                  onSubmitted: (v) => ref.read(cartProvider.notifier).updateItemQuantity(widget.index, double.tryParse(v) ?? 1),
                ),
              ),
              _qBtn(Icons.add, () {
                final cur = double.tryParse(_qtyCtrl.text) ?? 1;
                final n = cur + 1;
                _qtyCtrl.text = AppFormatters.formatQuantity(n);
                ref.read(cartProvider.notifier).updateItemQuantity(widget.index, n);
              }),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
            child: Text(item.unitName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.formatCurrency(item.subtotal),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${AppFormatters.formatCurrency(item.pricePerUnit)}/${item.unitName}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ]),
        ]),
      ]),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 26, height: 30, alignment: Alignment.center, child: Icon(icon, size: 14, color: AppColors.primary)),
  );
}

class _CartSummary extends ConsumerStatefulWidget {
  final CartState cart;
  const _CartSummary({required this.cart});
  @override ConsumerState<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends ConsumerState<_CartSummary> {
  final _discountCtrl = TextEditingController();

  @override
  void dispose() { _discountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Discount
        Row(children: [
          const Text('Diskon', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          SizedBox(
            width: 100, height: 32,
            child: TextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(hintText: '0', suffixText: '%', suffixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              onSubmitted: (v) => ref.read(cartProvider.notifier).setDiscountPercent(double.tryParse(v) ?? 0),
            ),
          ),
        ]),
        if (cart.discountAmount > 0) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Potongan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text('- ${AppFormatters.formatCurrency(cart.discountAmount)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ],
        const SizedBox(height: 6),
        // Tax toggle
        Row(children: [
          const Text('PPN 11%', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          Transform.scale(scale: 0.7, child: Switch(value: cart.taxEnabled, onChanged: (v) => ref.read(cartProvider.notifier).setTaxEnabled(v), activeColor: AppColors.primary)),
          if (cart.taxEnabled)
            Text(AppFormatters.formatCurrency(cart.taxAmount), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
        const Divider(color: AppColors.border),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(AppFormatters.formatCurrency(cart.total),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showDialog(context: context, barrierColor: Colors.black54, builder: (_) => const PaymentDialog()),
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Proses Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppColors.primary),
          ),
        ),
      ]),
    );
  }
}
