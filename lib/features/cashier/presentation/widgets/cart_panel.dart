import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import 'payment_dialog.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
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
                    return CartItemTile(
                      key: ValueKey('cart_item_${item.id}'),
                      item: item,
                    );
                  },
                ),
              ),
      ),

      // Totals & checkout
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(children: [
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

          _TotalRow(label: 'Subtotal', value: cart.grossSubtotal),

          if (cart.itemDiscountTotal > 0)
            _TotalRow(
                label: 'Potongan Item',
                value: -cart.itemDiscountTotal,
                valueColor: AppTheme.success),

          const SizedBox(height: 8),

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

class CartItemTile extends ConsumerStatefulWidget {
  final CartItem item;
  const CartItemTile({super.key, required this.item});

  @override
  ConsumerState<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<CartItemTile> {
  late TextEditingController _qtyCtrl;
  late FocusNode _qtyFocus;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _qtyFocus = FocusNode();
  }

  @override
  void didUpdateWidget(CartItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.quantity != widget.item.quantity) {
      if (!_qtyFocus.hasFocus) {
        _qtyCtrl.text = widget.item.quantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _qtyFocus.dispose();
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
          QtyButton(
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
              focusNode: _qtyFocus,
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
          QtyButton(
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
      builder: (context) => ItemEditDialog(item: item),
    );
  }
}

class ItemEditDialog extends ConsumerStatefulWidget {
  final CartItem item;
  const ItemEditDialog({super.key, required this.item});

  @override
  ConsumerState<ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends ConsumerState<ItemEditDialog> {
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

    _priceCtrl.addListener(() => setState(() {}));
    _discountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  double get _currentProfit {
    final price = double.tryParse(_priceCtrl.text) ?? widget.item.soldPrice;
    final disc = double.tryParse(_discountCtrl.text) ?? 0;

    double actualPrice = price;
    if (_discountType == DiscountType.percentage) {
      actualPrice -= (price * (disc / 100));
    } else {
      actualPrice -= disc;
    }

    return actualPrice - widget.item.costPrice;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(cartProvider.notifier);
    final profit = _currentProfit;
    final isNegativeProfit = profit < 0;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.item.product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Harga Modal: ${Formatters.currency(widget.item.costPrice)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
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
                    items: const [
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNegativeProfit ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isNegativeProfit ? AppTheme.danger : AppTheme.success),
            ),
            child: Row(
              children: [
                Icon(
                  isNegativeProfit ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                  color: isNegativeProfit ? AppTheme.danger : AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimasi Keuntungan',
                        style: TextStyle(
                          fontSize: 11,
                          color: isNegativeProfit ? AppTheme.danger : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        Formatters.currency(profit),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isNegativeProfit ? AppTheme.danger : AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isNegativeProfit)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Peringatan: Harga jual di bawah modal!',
                style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          onPressed: isNegativeProfit ? null : () {
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
          style: ElevatedButton.styleFrom(
            backgroundColor: isNegativeProfit ? AppTheme.textMuted : AppTheme.accent,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const QtyButton({super.key, required this.icon, required this.onTap});

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
