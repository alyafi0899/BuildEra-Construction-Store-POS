import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/multi_cart_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/cart_focus_provider.dart';
import 'payment_dialog.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      // Multi-Cart Tabs
      _CartTabsSection(),

      // Header
      _CartHeaderSection(),

      // Cart items
      _CartListSection(),

      // Totals & checkout
      _CartTotalsSection(),
    ]);
  }
}

class _CartTabsSection extends ConsumerWidget {
  const _CartTabsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiCart = ref.watch(multiCartProvider);
    final multiCartNotifier = ref.read(multiCartProvider.notifier);

    return Container(
      height: 48,
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
                children: List.generate(multiCart.carts.length, (index) {
                  final isActive = multiCart.activeIndex == index;
                  return _CartTabItem(
                    index: index,
                    isActive: isActive,
                    cartState: multiCart.carts[index],
                    onTap: () => multiCartNotifier.switchCart(index),
                    showRemove: multiCart.carts.length > 1,
                    onRemove: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Hapus Antrian',
                        content: 'Yakin hapus antrian #${index + 1}?',
                        confirmLabel: 'Hapus',
                        confirmColor: AppTheme.danger,
                      );
                      if (ok) multiCartNotifier.removeCart(index);
                    },
                  );
                }),
              ),
            ),
          ),
          const VerticalDivider(
              width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
          _TabsDropdown(state: multiCart, notifier: multiCartNotifier),
          const VerticalDivider(
              width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
          IconButton(
            onPressed: () => multiCartNotifier.addNewCart(),
            icon: const Icon(Icons.add_box_rounded,
                color: AppTheme.accent, size: 24),
            tooltip: 'Tambah Antrian',
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
    );
  }
}

class _TabsDropdown extends ConsumerWidget {
  final MultiCartState state;
  final MultiCartNotifier notifier;
  const _TabsDropdown({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppTheme.textSecondary),
      tooltip: 'Daftar Antrian',
      onSelected: (index) => notifier.switchCart(index),
      offset: const Offset(0, 48),
      itemBuilder: (context) => List.generate(state.carts.length, (index) {
        final isActive = state.activeIndex == index;
        final cart = isActive ? ref.watch(cartProvider) : state.carts[index];
        final name = cart.customerName?.isNotEmpty == true
            ? cart.customerName!
            : 'Antrian ${index + 1}';

        return PopupMenuItem<int>(
          value: index,
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : Icons.person_outline_rounded,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CartTabItem extends ConsumerWidget {
  final int index;
  final bool isActive;
  final CartState cartState;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool showRemove;

  const _CartTabItem({
    required this.index,
    required this.isActive,
    required this.cartState,
    required this.onTap,
    required this.onRemove,
    required this.showRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If active, watch the live cart provider for metadata changes
    final String? customerName = isActive
        ? ref.watch(cartProvider.select((s) => s.customerName))
        : cartState.customerName;

    final int itemCount = isActive
        ? ref.watch(cartProvider.select((s) => s.items.length))
        : cartState.items.length;

    final String numberLabel = (index + 1).toString();
    String? customerLabel;

    if (customerName?.isNotEmpty == true) {
      final names = customerName!.split(' ');
      if (names.length > 1) {
        customerLabel = '${names[0][0]}${names[1][0]}'.toUpperCase();
      } else {
        customerLabel =
            names[0].substring(0, names[0].length > 3 ? 3 : names[0].length);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: InkWell(
        onTap: onTap,
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
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                customerLabel != null
                    ? '$numberLabel. $customerLabel'
                    : numberLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              if (itemCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white24
                          : AppTheme.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$itemCount',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : AppTheme.warning,
                      ),
                    ),
                  ),
                ),
              if (showRemove) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onRemove,
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
  }
}

class _CartHeaderSection extends ConsumerWidget {
  const _CartHeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartProvider.select((s) => s.items.length));
    final isEmpty = ref.watch(cartProvider.select((s) => s.isEmpty));

    return Container(
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
        if (itemCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$itemCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        const Spacer(),
        if (!isEmpty)
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
    );
  }
}

class _CartListSection extends ConsumerStatefulWidget {
  const _CartListSection();

  @override
  ConsumerState<_CartListSection> createState() => _CartListSectionState();
}

class _CartListSectionState extends ConsumerState<_CartListSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(cartProvider.select((s) => s.items.length));
    final isEmpty = itemCount == 0;

    return Expanded(
      child: isEmpty
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
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  // We only watch the ID at this level to avoid full list rebuilds
                  final itemId = ref.read(cartProvider).items[i].id;
                  return CartItemTile(
                    key: ValueKey('cart_item_$itemId'),
                    itemId: itemId,
                  );
                },
              ),
            ),
    );
  }
}

class _CartTotalsSection extends ConsumerStatefulWidget {
  const _CartTotalsSection();

  @override
  ConsumerState<_CartTotalsSection> createState() => _CartTotalsSectionState();
}

class _CartTotalsSectionState extends ConsumerState<_CartTotalsSection> {
  late final TextEditingController _discountCtrl;
  late final FocusNode _discountFocus;
  late final TextEditingController _customerCtrl;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _discountCtrl = TextEditingController(
        text: cart.transDiscountValue == 0
            ? ''
            : cart.transDiscountValue.toStringAsFixed(0));
    _discountFocus = FocusNode();
    _customerCtrl = TextEditingController(text: cart.customerName ?? '');
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _discountFocus.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch granularly to avoid rebuilding the whole footer on small changes
    final grossSubtotal =
        ref.watch(cartProvider.select((s) => s.grossSubtotal));
    final itemDiscountTotal =
        ref.watch(cartProvider.select((s) => s.itemDiscountTotal));
    final transDiscountValue =
        ref.watch(cartProvider.select((s) => s.transDiscountValue));
    final transDiscountType =
        ref.watch(cartProvider.select((s) => s.transDiscountType));
    final taxEnabled = ref.watch(cartProvider.select((s) => s.taxEnabled));
    final taxAmount = ref.watch(cartProvider.select((s) => s.taxAmount));
    final total = ref.watch(cartProvider.select((s) => s.total));
    final isEmpty = ref.watch(cartProvider.select((s) => s.isEmpty));
    final focus = ref.watch(cartTotalsFocusProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(children: [
        TextField(
          controller: _customerCtrl,
          focusNode: focus.customerFocus,
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
          onSubmitted: (_) => isEmpty ? null : PaymentDialog.show(context),
        ),
        const SizedBox(height: 12),
        _TotalRow(label: 'Subtotal', value: grossSubtotal),
        if (itemDiscountTotal > 0)
          _TotalRow(
              label: 'Potongan Item',
              value: -itemDiscountTotal,
              valueColor: AppTheme.success),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Diskon Transaksi',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 50,
            child: DropdownButton<DiscountType>(
              value: transDiscountType,
              isDense: true,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: AppTheme.accent),
              items: const [
                DropdownMenuItem(value: DiscountType.fixed, child: Text('Rp')),
                DropdownMenuItem(
                    value: DiscountType.percentage, child: Text('%')),
              ],
              onChanged: (v) => ref
                  .read(cartProvider.notifier)
                  .setTransDiscount(transDiscountValue, v!),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ScrollableQtyField(
              controller: _discountCtrl,
              step: 1000,
              onChanged: (v) => ref
                  .read(cartProvider.notifier)
                  .setTransDiscount(v, transDiscountType),
              child: TextField(
                controller: _discountCtrl,
                focusNode: focus.transDiscountFocus,
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
                  final numericValue = Formatters.parsePrice(v);
                  ref.read(cartProvider.notifier).setTransDiscount(
                      numericValue, transDiscountType);
                },
                inputFormatters: [CurrencyInputFormatter()],
                onSubmitted: (_) =>
                    isEmpty ? null : PaymentDialog.show(context),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('PPN (11%)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Switch.adaptive(
            value: taxEnabled,
            onChanged: (_) => ref.read(cartProvider.notifier).toggleTax(),
            activeTrackColor: AppTheme.accent,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              Formatters.currency(taxAmount),
              textAlign: TextAlign.right,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          Text(Formatters.currency(total),
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
            onPressed: isEmpty ? null : () => PaymentDialog.show(context),
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
  final String itemId;
  const CartItemTile({super.key, required this.itemId});

  @override
  ConsumerState<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<CartItemTile> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late FocusNode _qtyFocus;
  late FocusNode _priceFocus;
  late FocusNode _discountFocus;
  bool _showProfit = false;

  @override
  void initState() {
    super.initState();
    final item =
        ref.read(cartProvider).items.firstWhere((i) => i.id == widget.itemId);
    _qtyCtrl = TextEditingController(text: item.quantity.toString());
    _priceCtrl = TextEditingController(text: item.soldPrice.toStringAsFixed(0));
    _discountCtrl =
        TextEditingController(text: item.discountValue.toStringAsFixed(0));
    
    _qtyFocus = FocusNode(debugLabel: 'QtyFocus_${widget.itemId}');
    _priceFocus = FocusNode(debugLabel: 'PriceFocus_${widget.itemId}');
    _discountFocus = FocusNode(debugLabel: 'DiscFocus_${widget.itemId}');

    // Register focus nodes to global registry for shortcut access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartFocusRegistryProvider.notifier).register(
            widget.itemId,
            CartItemFocusNodes(
              qtyFocus: _qtyFocus,
              priceFocus: _priceFocus,
              discountFocus: _discountFocus,
            ),
          );
    });
  }

  @override
  void dispose() {
    // SAFE FIX: Use ref.container.read instead of ref.read during dispose to avoid unmounted error
    try {
      ref.container.read(cartFocusRegistryProvider.notifier).unregister(widget.itemId);
    } catch (_) {}

    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _verifyPinAndShowProfit() async {
    if (_showProfit) {
      setState(() => _showProfit = false);
      return;
    }

    final settings = ref.read(settingsProvider);
    final correctPin = settings.securityPin ?? '1234';

    final pinController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akses Keuntungan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan PIN untuk melihat estimasi keuntungan.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'PIN Keamanan',
                hintText: 'Masukkan PIN Owner',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
              onSubmitted: (_) {
                if (pinController.text == correctPin) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN Salah!')));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == correctPin) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('PIN Salah!')));
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
    final item = ref.watch(cartProvider.select(
      (s) => s.items.isEmpty
          ? null
          : s.items
              .cast<CartItem?>()
              .firstWhere((i) => i?.id == widget.itemId, orElse: () => null),
    ));

    if (item == null) return const SizedBox.shrink();

    final notifier = ref.read(cartProvider.notifier);

    // Sync controllers if changed externally
    if (!_qtyFocus.hasFocus) {
      final qStr = item.quantity % 1 == 0 
          ? item.quantity.toInt().toString() 
          : item.quantity.toStringAsFixed(5).replaceAll(RegExp(r'\.?0+$'), '');
      if (_qtyCtrl.text != qStr) {
        _qtyCtrl.text = qStr;
      }
    }

    final priceStr = item.soldPrice.toStringAsFixed(0);
    if (_priceCtrl.text != priceStr) {
      _priceCtrl.text = priceStr;
      _priceCtrl.selection =
          TextSelection.collapsed(offset: _priceCtrl.text.length);
    }

    final discountStr = item.discountValue.toStringAsFixed(0);
    if (_discountCtrl.text != discountStr) {
      _discountCtrl.text = discountStr;
      _discountCtrl.selection =
          TextSelection.collapsed(offset: _discountCtrl.text.length);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 6. Name Alignment Middle
            children: [
              // 1. Product Name (Wrapped & Centered)
              Expanded(
                flex: 4,
                child: Text(
                  item.product.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),

              // 5. Divider between Name and Input
              const SizedBox(
                height: 32,
                child: VerticalDivider(width: 1, color: AppTheme.border),
              ),
              const SizedBox(width: 12),

              // 2. Unit Section
              _CartInputGroup(
                label: 'Unit', // 1. Separate Unit Label
                child: _StandardBox(
                  width: 65,
                  child: item.product.allUnits.length > 1
                      ? DropdownButton<String>(
                          value: item.selectedUnit.unitName,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: AppTheme.surfaceAlt,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                          items: item.product.allUnits
                              .map((u) => DropdownMenuItem(
                                    value: u.unitName,
                                    child: Text(u.unitName),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            final u = item.product.allUnits
                                .firstWhere((u) => u.unitName == v);
                            notifier.updateUnit(item.id, u);
                          },
                        )
                      : Center(
                          child: Text(item.selectedUnit.unitName,
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. QTY Section with +/- Buttons
              _CartInputGroup(
                label: 'Qty', // 1. Separate Qty Label
                child: Row(
                  children: [
                    // 2. Minus Button
                    QtyButton(
                        icon: Icons.remove,
                        onTap: () {
                          final q = item.quantity - 1;
                          if (q >= 1) { // Changed from 0 to 1
                            notifier.updateQuantity(item.id, q);
                            _qtyCtrl.text = q % 1 == 0 ? q.toInt().toString() : q.toString();
                          }
                        }),
                    const SizedBox(width: 4),
                    _StandardBox(
                      width: 45,
                      child: ScrollableQtyField(
                        controller: _qtyCtrl,
                        onChanged: (v) {
                          if (v >= 1) { // Changed from 0 to 1
                            notifier.updateQuantity(item.id, v);
                          }
                        },
                        child: TextField(
                          controller: _qtyCtrl,
                          focusNode: _qtyFocus,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (v) {
                            final qty = Formatters.parseQuantity(v);
                            if (qty >= 1) { // Changed from 0 to 1
                              notifier.updateQuantity(item.id, qty);
                            }
                          },
                          onSubmitted: (v) => notifier.updateQuantity(
                              item.id,
                              Formatters.parseQuantity(v) >= 1 // Changed from 0 to 1
                                  ? Formatters.parseQuantity(v)
                                  : 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 2. Plus Button
                    QtyButton(
                        icon: Icons.add,
                        onTap: () {
                          final q = item.quantity + 1;
                          notifier.updateQuantity(item.id, q);
                          _qtyCtrl.text = q % 1 == 0 ? q.toInt().toString() : q.toString();
                        }),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 3. Harga Jual
              _CartInputGroup(
                label: 'Harga Jual',
                child: _StandardBox(
                  width: 110,
                  child: ScrollableQtyField(
                    controller: _priceCtrl,
                    step: 1000,
                    onChanged: (v) => notifier.updateSoldPrice(item.id, v),
                    child: _InlineTextField(
                      key: ValueKey(
                          'price_${item.id}_${item.selectedUnit.unitName}'),
                      controller: _priceCtrl,
                      focusNode: _priceFocus,
                      initialValue: item.soldPrice.toStringAsFixed(0),
                      onChanged: (v) => notifier.updateSoldPrice(
                          item.id,
                          Formatters.parsePrice(v) > 0
                              ? Formatters.parsePrice(v)
                              : item.originalPrice),
                      prefixText: 'Rp ',
                      isBare: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 4. Diskon
              _CartInputGroup(
                label: 'Diskon',
                child: Row(
                  children: [
                    _StandardBox(
                      width: 70,
                      child: ScrollableQtyField(
                        controller: _discountCtrl,
                        step: 1000,
                        onChanged: (v) =>
                            notifier.setItemDiscount(item.id, v, item.discountType),
                        child: _InlineTextField(
                          key: ValueKey('discount_${item.id}'),
                          controller: _discountCtrl,
                          focusNode: _discountFocus,
                          initialValue: item.discountValue.toStringAsFixed(0),
                          onChanged: (v) => notifier.setItemDiscount(
                              item.id,
                              Formatters.parsePrice(v),
                              item.discountType),
                          isBare: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _StandardBox(
                      width: 45,
                      child: DropdownButton<DiscountType>(
                        value: item.discountType,
                        underline: const SizedBox(),
                        isDense: true,
                        isExpanded: true,
                        alignment: Alignment.center,
                        icon: const SizedBox(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(
                              value: DiscountType.fixed,
                              child: Center(child: Text('Rp'))),
                          DropdownMenuItem(
                              value: DiscountType.percentage,
                              child: Center(child: Text('%'))),
                        ],
                        onChanged: (v) => notifier.setItemDiscount(
                            item.id, item.discountValue, v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 3. Divider between Input and Total
              const SizedBox(
                height: 32,
                child: VerticalDivider(width: 1, color: AppTheme.border),
              ),
              const SizedBox(width: 16),

              // 5. Total Price & Profit Icon
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Align items in the middle vertically
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 4. Small Label above Total Price
                    const Text('Total Harga', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.totalDiscount > 0)
                              Text('-${Formatters.currency(item.totalDiscount)}',
                                  style: const TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            Text(Formatters.currency(item.subtotal),
                                style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        _ProfitToggleIcon(
                          item: item,
                          isActive: _showProfit,
                          onTap: _verifyPinAndShowProfit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Divider before Remove Button
              const SizedBox(
                height: 32,
                child: VerticalDivider(width: 1, color: AppTheme.border),
              ),

              // 6. Remove Button
              IconButton(
                onPressed: () => notifier.removeItem(item.id),
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: AppTheme.textMuted),
                padding: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Expanded Profit Details
          if (_showProfit) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _ProfitDetailRow(
                      label: 'Harga Modal Unit', value: item.costPrice),
                  _ProfitDetailRow(
                      label: 'Total Estimasi Untung',
                      value: item.profit,
                      isBold: true),
                  _ProfitDetailRow(
                      label: 'Margin Profit',
                      value: (item.profit /
                              (item.subtotal > 0 ? item.subtotal : 1)) *
                          100,
                      isPercent: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartInputGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _CartInputGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

class _ProfitToggleIcon extends StatelessWidget {
  final CartItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfitToggleIcon({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final margin = item.subtotal > 0 ? (item.profit / item.subtotal) : 0;
    final isLowMargin = margin < 0.1;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accent
              : (isLowMargin
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive
                  ? AppTheme.accent
                  : (isLowMargin ? AppTheme.danger : AppTheme.success),
              width: 0.8),
        ),
        child: Icon(
          isActive ? Icons.lock_open_rounded : Icons.show_chart_rounded,
          size: 14,
          color: isActive
              ? Colors.white
              : (isLowMargin ? AppTheme.danger : AppTheme.success),
        ),
      ),
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
          Text(widget.item.product.name,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    decoration:
                        const InputDecoration(labelText: 'Tipe', isDense: true),
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
              color: isNegativeProfit
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isNegativeProfit ? AppTheme.danger : AppTheme.success),
            ),
            child: Row(
              children: [
                Icon(
                  isNegativeProfit
                      ? Icons.warning_amber_rounded
                      : Icons.trending_up_rounded,
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
                          color: isNegativeProfit
                              ? AppTheme.danger
                              : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        Formatters.currency(profit),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isNegativeProfit
                              ? AppTheme.danger
                              : AppTheme.success,
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
                style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          onPressed: isNegativeProfit
              ? null
              : () {
                  final price =
                      double.tryParse(_priceCtrl.text) ?? widget.item.soldPrice;
                  final disc = double.tryParse(_discountCtrl.text) ?? 0;

                  if (price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Harga harus lebih dari 0')));
                    return;
                  }

                  notifier.updateSoldPrice(widget.item.id, price);
                  notifier.setItemDiscount(widget.item.id, disc, _discountType);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isNegativeProfit ? AppTheme.textMuted : AppTheme.accent,
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
  final bool isBare;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const _InlineTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.prefixText,
    this.isBare = false,
    this.controller,
    this.focusNode,
  });

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InlineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final effectiveController = widget.controller ?? _controller;
    final isFocused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    if (oldWidget.initialValue != widget.initialValue && !isFocused) {
      effectiveController.text = widget.initialValue;
      effectiveController.selection = TextSelection.collapsed(
        offset: effectiveController.text.length,
      );
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveController = widget.controller ?? _controller;

    if (widget.isBare) {
      return TextField(
        controller: effectiveController,
        focusNode: widget.focusNode,
        onChanged: (v) {
          widget.onChanged(v);
        },
        inputFormatters: [CurrencyInputFormatter()],
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          prefixText: widget.prefixText,
          prefixStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: TextField(
        controller: effectiveController,
        focusNode: widget.focusNode,
        onChanged: (v) {
          widget.onChanged(v);
        },
        inputFormatters: [CurrencyInputFormatter()],
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

class _StandardBox extends StatelessWidget {
  final Widget child;
  final double? width;

  const _StandardBox({required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      alignment: Alignment.center,
      child: child,
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
            : (isLowMargin
                ? AppTheme.danger.withValues(alpha: 0.1)
                : AppTheme.success.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isActive
                ? AppTheme.accent
                : (isLowMargin ? AppTheme.danger : AppTheme.success),
            width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.lock_open_rounded : Icons.show_chart_rounded,
            size: 12,
            color: isActive
                ? Colors.white
                : (isLowMargin ? AppTheme.danger : AppTheme.success),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'TUTUP DETAIL' : 'CEK UNTUNG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isActive
                  ? Colors.white
                  : (isLowMargin ? AppTheme.danger : AppTheme.success),
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
    final color = value < 0
        ? AppTheme.danger
        : (label.contains('Untung') || isPercent
            ? AppTheme.success
            : AppTheme.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            isPercent
                ? '${value.toStringAsFixed(1)}%'
                : Formatters.currency(value),
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
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
