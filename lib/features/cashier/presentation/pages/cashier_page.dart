import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
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
import 'scanner_page.dart';

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
  bool _showCartOnCompact = false;

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
    bool isInAnyInputField =
        primaryFocus != null && primaryFocus.context?.widget is EditableText;

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
    final cart = ref.watch(cartProvider);
    final supportsCameraScanner = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    Widget buildProductPanel({required bool compact}) => Column(
          children: [
            PageHeader(
              title: 'Kasir',
              icon: Icons.point_of_sale_rounded,
              actions: compact
                  ? const []
                  : [
                      const SizedBox(width: 16),
                      Text(Formatters.date(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 24, vertical: compact ? 8 : 16),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Expanded(
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
                  if (supportsCameraScanner) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          final scanned = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScannerPage()),
                          );
                          if (scanned == true && mounted) {
                            setState(() => _showCartOnCompact = true);
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            color: AppTheme.accent),
                        tooltip: 'Buka Kamera Scanner',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _CategoryFilter(
              selected: category,
              onSelected: (c) =>
                  ref.read(productCategoryFilterProvider.notifier).set(c),
            ),
            Expanded(
              child:
                  _ProductGrid(onAction: () => _searchFocusNode.requestFocus()),
            ),
          ],
        );

    Widget buildCartPanel({required bool compact}) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: compact
                ? null
                : const Border(left: BorderSide(color: AppTheme.border)),
          ),
          child: const CartPanel(),
        );

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
          LogicalKeySet(LogicalKeyboardKey.shiftRight):
              const OpenPaymentIntent(),
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
                  ref
                      .read(cartFocusRegistryProvider)[lastId]
                      ?.qtyFocus
                      .requestFocus();
                }
                return null;
              },
            ),
            FocusPriceIntent: CallbackAction<FocusPriceIntent>(
              onInvoke: (_) {
                final items = ref.read(cartProvider).items;
                if (items.isNotEmpty) {
                  final lastId = items.last.id;
                  ref
                      .read(cartFocusRegistryProvider)[lastId]
                      ?.priceFocus
                      .requestFocus();
                }
                return null;
              },
            ),
            FocusItemDiscIntent: CallbackAction<FocusItemDiscIntent>(
              onInvoke: (_) {
                final items = ref.read(cartProvider).items;
                if (items.isNotEmpty) {
                  final lastId = items.last.id;
                  ref
                      .read(cartFocusRegistryProvider)[lastId]
                      ?.discountFocus
                      .requestFocus();
                }
                return null;
              },
            ),
            FocusTransDiscIntent: CallbackAction<FocusTransDiscIntent>(
              onInvoke: (_) {
                ref
                    .read(cartTotalsFocusProvider)
                    .transDiscountFocus
                    .requestFocus();
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = ResponsiveBreakpoints.useCompactCashier(
                    constraints.maxWidth);
                if (!compact) {
                  return Row(
                    children: [
                      Expanded(child: buildProductPanel(compact: false)),
                      Expanded(child: buildCartPanel(compact: false)),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          const ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.search_rounded),
                            label: Text('Produk'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: const Icon(Icons.shopping_cart_outlined),
                            label: Text('Keranjang (${cart.itemCount})'),
                          ),
                        ],
                        selected: {_showCartOnCompact},
                        onSelectionChanged: (selection) {
                          setState(() => _showCartOnCompact = selection.first);
                          if (!selection.first) {
                            _searchFocusNode.requestFocus();
                          } else {
                            FocusManager.instance.primaryFocus?.unfocus();
                          }
                        },
                      ),
                    ),
                    if (_showCartOnCompact)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total ${Formatters.currency(cart.total)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    Expanded(
                      child: _showCartOnCompact
                          ? buildCartPanel(compact: true)
                          : buildProductPanel(compact: true),
                    ),
                  ],
                );
              },
            ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(compact ? 12 : 20),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: compact ? 220 : 250,
              mainAxisSpacing: compact ? 10 : 14,
              crossAxisSpacing: compact ? 10 : 14,
              mainAxisExtent: compact ? 238 : 270,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => RepaintBoundary(
              child: _ProductCard(
                key: ValueKey('cashier_prod_${products[i].id}'),
                product: products[i],
                onAction: widget.onAction,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback? onAction;
  const _ProductCard({super.key, required this.product, this.onAction});

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
          ref.read(barcodeScannerProvider.notifier).clearBuffer();
          onAction?.call();
        },
        onLongPress: () => ProductDetailDialog.show(context, product),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isLow
                  ? AppTheme.warning.withValues(alpha: 0.4)
                  : AppTheme.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(imagePath: product.imagePath),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Detail produk',
                        onPressed: () =>
                            ProductDetailDialog.show(context, product),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${Formatters.decimal(product.stock)} ${product.baseUnit}',
                          style: TextStyle(
                            color:
                                isLow ? AppTheme.warning : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.currency(product.basePrice),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(Icons.add_circle_outline_rounded,
                            color: AppTheme.accent, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
