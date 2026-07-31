import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/multi_cart_provider.dart';
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
    final multiCart = ref.watch(multiCartProvider);
    final multiCartNotifier = ref.read(multiCartProvider.notifier);

    return Column(children: [
      // Multi-Cart Tabs
      _cartTabs(context, multiCart, multiCartNotifier),

      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                    content: 'Yakin kosongkan semua item di antrian ini?',
                    confirmLabel: 'Kosongkan',
                    confirmColor: AppTheme.warning);
                if (ok) ref.read(cartProvider.notifier).clear();
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Hapus Item'),
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
                onChanged: (v) {
                  final numericValue = v.replaceAll('.', '');
                  ref.read(cartProvider.notifier).setTransDiscount(
                      double.tryParse(numericValue) ?? 0, cart.transDiscountType);
                },
                inputFormatters: [CurrencyInputFormatter()],
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

  Widget _cartTabs(BuildContext context, MultiCartState state, MultiCartNotifier notifier) {
    return Container(
      height: 48, // Increased height for better tap target and visibility
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: List.generate(state.carts.length, (index) {
                  final isActive = state.activeIndex == index;
                  final cart = isActive ? ref.watch(cartProvider) : state.carts[index];
                  
                  // Label logic: Icon + Number, or Icon + Customer Initial
                  final String numberLabel = (index + 1).toString();
                  String? customerLabel;
                  
                  if (cart.customerName?.isNotEmpty == true) {
                    final names = cart.customerName!.split(' ');
                    if (names.length > 1) {
                      customerLabel = '${names[0][0]}${names[1][0]}'.toUpperCase();
                    } else {
                      customerLabel = names[0].substring(0, names[0].length > 3 ? 3 : names[0].length);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: InkWell(
                      onTap: () => notifier.switchCart(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.accent : AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? AppTheme.accent : AppTheme.border,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Queue Icon instead of word "Antrian"
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: isActive ? Colors.white : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              customerLabel != null ? '$numberLabel. $customerLabel' : numberLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            if (cart.itemCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white24 : AppTheme.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${cart.itemCount}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.white : AppTheme.warning,
                                    ),
                                  ),
                                ),
                              ),
                            if (state.carts.length > 1) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  final ok = await showConfirmDialog(
                                    context,
                                    title: 'Hapus Antrian',
                                    content: 'Yakin hapus antrian #${index + 1}?',
                                    confirmLabel: 'Hapus',
                                    confirmColor: AppTheme.danger,
                                  );
                                  if (ok) notifier.removeCart(index);
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isActive ? Colors.white70 : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
          // Dropdown for many tabs
          _tabsDropdown(state, notifier),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
          IconButton(
            onPressed: () => notifier.addNewCart(),
            icon: const Icon(Icons.add_box_rounded, color: AppTheme.accent, size: 24),
            tooltip: 'Tambah Antrian',
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
    );
  }

  Widget _tabsDropdown(MultiCartState state, MultiCartNotifier notifier) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
      tooltip: 'Daftar Antrian',
      onSelected: (index) => notifier.switchCart(index),
      offset: const Offset(0, 48),
      itemBuilder: (context) => List.generate(state.carts.length, (index) {
        final cart = state.activeIndex == index ? ref.watch(cartProvider) : state.carts[index];
        final isActive = state.activeIndex == index;
        final name = cart.customerName?.isNotEmpty == true ? cart.customerName! : 'Antrian ${index + 1}';
        
        return PopupMenuItem<int>(
          value: index,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                size: 18,
                color: isActive ? AppTheme.accent : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppTheme.accent : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (cart.itemCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warning),
                  ),
                ),
            ],
          ),
        );
      }),
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

class CartItemTile extends ConsumerStatefulWidget {
  final CartItem item;
  const CartItemTile({super.key, required this.item});

  @override
  ConsumerState<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<CartItemTile> {
  late TextEditingController _qtyCtrl;
  late FocusNode _qtyFocus;
  bool _showProfit = false;

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

  void _verifyPinAndShowProfit() async {
    if (_showProfit) {
      setState(() => _showProfit = false);
      return;
    }

    final pinController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akses Keuntungan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan PIN untuk melihat estimasi keuntungan.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'PIN Owner',
                hintText: 'Default: 1234',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
              onSubmitted: (_) {
                 if (pinController.text == '1234') {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Salah!')));
                  }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              // Default PIN 1234
              if (pinController.text == '1234') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Salah!')));
              }
            },
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _showProfit = true);
    }
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
            child: ScrollableQtyField(
              controller: _qtyCtrl,
              onChanged: (v) => notifier.updateQuantity(item.id, v),
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
          ),
          QtyButton(
              icon: Icons.add,
              onTap: () {
                final q = item.quantity + 1;
                notifier.updateQuantity(item.id, q);
                _qtyCtrl.text = q.toString();
              }),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppTheme.border),
        const SizedBox(height: 12),
        
        // Inline Pricing Controls
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price Override
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Harga Jual (Override)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  _InlineTextField(
                    key: ValueKey('price_${item.id}'), // Fixed key to prevent rebuild lag
                    initialValue: item.soldPrice.toStringAsFixed(0),
                    onChanged: (v) => notifier.updateSoldPrice(item.id, double.tryParse(v) ?? item.originalPrice),
                    prefixText: 'Rp ',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Discount Settings
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Potongan Item', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineTextField(
                          key: ValueKey('discount_${item.id}'), // Fixed key to prevent rebuild lag
                          initialValue: item.discountValue.toStringAsFixed(0),
                          onChanged: (v) => notifier.setItemDiscount(item.id, double.tryParse(v) ?? 0, item.discountType),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButton<DiscountType>(
                          value: item.discountType,
                          underline: const SizedBox(),
                          isDense: true,
                          style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: DiscountType.fixed, child: Text('Rp')),
                            DropdownMenuItem(value: DiscountType.percentage, child: Text('%')),
                          ],
                          onChanged: (v) => notifier.setItemDiscount(item.id, item.discountValue, v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Profit Indicator and Subtotal
        Row(
          children: [
            GestureDetector(
              onTap: _verifyPinAndShowProfit,
              child: _ProfitIndicator(item: item, isActive: _showProfit),
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
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ],
        ),

        // Expanded Profit Details
        if (_showProfit) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _ProfitDetailRow(label: 'Harga Modal Unit', value: item.costPrice),
                _ProfitDetailRow(label: 'Total Estimasi Untung', value: item.profit, isBold: true),
                _ProfitDetailRow(
                  label: 'Margin Profit', 
                  value: (item.profit / (item.subtotal > 0 ? item.subtotal : 1)) * 100, 
                  isPercent: true
                ),
              ],
            ),
          ),
        ],
      ]),
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

class _InlineTextField extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;
  final String? prefixText;

  const _InlineTextField({super.key, required this.initialValue, required this.onChanged, this.prefixText});

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InlineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      // Only update if not focused to avoid cursor jumping
      if (!FocusScope.of(context).hasFocus) {
         _controller.text = widget.initialValue;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        onChanged: (v) {
          final numericValue = v.replaceAll('.', '');
          widget.onChanged(numericValue);
        },
        inputFormatters: [CurrencyInputFormatter()],
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          prefixText: widget.prefixText,
          prefixStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ProfitIndicator extends StatelessWidget {
  final CartItem item;
  final bool isActive;
  const _ProfitIndicator({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final margin = item.subtotal > 0 ? (item.profit / item.subtotal) : 0;
    final isLowMargin = margin < 0.1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive 
            ? AppTheme.accent 
            : (isLowMargin ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? AppTheme.accent : (isLowMargin ? AppTheme.danger : AppTheme.success),
          width: 0.8
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.lock_open_rounded : Icons.show_chart_rounded,
            size: 12,
            color: isActive ? Colors.white : (isLowMargin ? AppTheme.danger : AppTheme.success),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'TUTUP DETAIL' : 'CEK UNTUNG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.white : (isLowMargin ? AppTheme.danger : AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitDetailRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final bool isPercent;

  const _ProfitDetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = value < 0 ? AppTheme.danger : (label.contains('Untung') || isPercent ? AppTheme.success : AppTheme.textPrimary);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            isPercent ? '${value.toStringAsFixed(1)}%' : Formatters.currency(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
