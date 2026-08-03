import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../products/providers/product_provider.dart';

import '../../providers/cart_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../../providers/barcode_scanner_provider.dart';
import '../widgets/cart_panel.dart';
import '../widgets/barcode_listener.dart';
import '../widgets/cashier_intents.dart';
import '../../providers/cart_focus_provider.dart';
import '../widgets/payment_dialog.dart';

import '../../../../shared/widgets/product_detail_dialog.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'CashierSearchFocus');
  Timer? _unfocusTimer;

  @override
  void initState() {
    super.initState();
    // Initial focus on search bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _unfocusTimer?.cancel();
    super.dispose();
  }

  void _reclaimFocus() {
    if (!mounted) return;
    
    // Rule 3: Do NOT reclaim if a modal dialog is open
    if (ModalRoute.of(context)?.isCurrent == false) return;

    final primaryFocus = FocusManager.instance.primaryFocus;
    
    // Rule 2: Absolute Protection for Cart fields
    // We check if the focus is on an EditableText (input field).
    // If it is, we NEVER pull back.
    bool isInAnyInputField = primaryFocus != null && 
                            primaryFocus.context?.widget is EditableText;

    if (isInAnyInputField) return;

    // Only reclaim if focus is null or lost to a non-input area
    _searchFocusNode.requestFocus();
  }

  void _resetUnfocusTimer() {
    _unfocusTimer?.cancel();
    
    if (ModalRoute.of(context)?.isCurrent == false) return;

    // Rule 2: If we are in an input field, DO NOT start the timer.
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context?.widget is EditableText) {
      return;
    }

    _unfocusTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _reclaimFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(productCategoryFilterProvider);

    // Listen to global barcode events
    ref.listen<BarcodeEvent?>(barcodeEventProvider, (prev, next) {
      if (next == null) return;
      
      _unfocusTimer?.cancel();

      if (!next.wasFocused) {
        _searchCtrl.clear();
        ref.read(productSearchQueryProvider.notifier).set('');
        _searchFocusNode.requestFocus();
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
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): const EscFocusIntent(),
          SingleActivator(LogicalKeyboardKey.f1): const FocusQtyIntent(),
          SingleActivator(LogicalKeyboardKey.f2): const FocusPriceIntent(),
          SingleActivator(LogicalKeyboardKey.f3): const FocusItemDiscIntent(),
          SingleActivator(LogicalKeyboardKey.f4): const FocusTransDiscIntent(),
          SingleActivator(LogicalKeyboardKey.f5): const FocusCustomerIntent(),
          LogicalKeySet(LogicalKeyboardKey.altLeft): const ToggleTaxIntent(),
          LogicalKeySet(LogicalKeyboardKey.altRight): const ToggleTaxIntent(),
          LogicalKeySet(LogicalKeyboardKey.shiftRight): const OpenPaymentIntent(),
        },
        child: Actions(
          actions: {
            EscFocusIntent: CallbackAction<EscFocusIntent>(
              onInvoke: (_) {
                _searchFocusNode.requestFocus();
                _unfocusTimer?.cancel();
                return null;
              },
            ),
            FocusQtyIntent: CallbackAction<FocusQtyIntent>(
              onInvoke: (_) {
                final items = ref.read(cartProvider).items;
                if (items.isNotEmpty) {
                  final lastId = items.last.id;
                  ref.read(cartFocusRegistryProvider)[lastId]?.qtyFocus.requestFocus();
                }
                return null;
              },
            ),
            FocusPriceIntent: CallbackAction<FocusPriceIntent>(
              onInvoke: (_) {
                final items = ref.read(cartProvider).items;
                if (items.isNotEmpty) {
                  final lastId = items.last.id;
                  ref.read(cartFocusRegistryProvider)[lastId]?.priceFocus.requestFocus();
                }
                return null;
              },
            ),
            FocusItemDiscIntent: CallbackAction<FocusItemDiscIntent>(
              onInvoke: (_) {
                final items = ref.read(cartProvider).items;
                if (items.isNotEmpty) {
                  final lastId = items.last.id;
                  ref.read(cartFocusRegistryProvider)[lastId]?.discountFocus.requestFocus();
                }
                return null;
              },
            ),
            FocusTransDiscIntent: CallbackAction<FocusTransDiscIntent>(
              onInvoke: (_) {
                ref.read(cartTotalsFocusProvider).transDiscountFocus.requestFocus();
                return null;
              },
            ),
            FocusCustomerIntent: CallbackAction<FocusCustomerIntent>(
              onInvoke: (_) {
                ref.read(cartTotalsFocusProvider).customerFocus.requestFocus();
                return null;
              },
            ),
            ToggleTaxIntent: CallbackAction<ToggleTaxIntent>(
              onInvoke: (_) {
                ref.read(cartProvider.notifier).toggleTax();
                return null;
              },
            ),
            OpenPaymentIntent: CallbackAction<OpenPaymentIntent>(
              onInvoke: (_) {
                if (!ref.read(cartProvider).isEmpty) {
                  PaymentDialog.show(context);
                }
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Reset timer on any click
              _resetUnfocusTimer();
              // Short delay to let the click focus the target field first
              Future.delayed(const Duration(milliseconds: 150), _reclaimFocus);
            },
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

                      // Search Field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        color: AppTheme.surface,
                        child: AppSearchField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          hintText: 'Cari produk atau scan barcode...',
                          onChanged: (v) {
                            ref.read(productSearchQueryProvider.notifier).set(v);
                            _resetUnfocusTimer();
                          },
                          onClear: () {
                            _searchCtrl.clear();
                            ref.read(productSearchQueryProvider.notifier).set('');
                            _searchFocusNode.requestFocus();
                          },
                          onSubmitted: (v) {
                            ref.read(productSearchQueryProvider.notifier).set(v);
                            ref.read(barcodeScannerProvider.notifier).clearBuffer();
                            _searchFocusNode.requestFocus();
                            _unfocusTimer?.cancel();
                          },
                        ),
                      ),

                      // Category filter chips
                      _CategoryFilter(
                        selected: category,
                        onSelected: (c) => ref.read(productCategoryFilterProvider.notifier).set(c),
                      ),

                      // Product grid
                    Expanded(
                        child: _ProductGrid(onAction: () => _searchFocusNode.requestFocus())),
                  ]),
              ),

              // ── Right: Cart Panel ────────────────────────────────────────────
              Container(
                width: 480,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(left: BorderSide(color: AppTheme.border)),
                ),
                child: const CartPanel(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ClearFocusIntent extends Intent {
  const ClearFocusIntent();
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
  final VoidCallback? onAction;
  const _ProductGrid({this.onAction});

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
            onTap: widget.onAction,
          ),
        ),
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  final Product product;
  final VoidCallback? onTap;
  const _ProductListTile({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.isLowStock;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(cartProvider.notifier).addProduct(product);
          // Rule 1: Instant Pull back to search after manual add
          ref.read(barcodeScannerProvider.notifier).clearBuffer();
          if (onTap != null) onTap!();
        },
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
