import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../products/providers/product_provider.dart';
import '../../../products/presentation/widgets/product_form_dialog.dart';
import '../../providers/purchase_cart_provider.dart';
import '../widgets/purchase_cart_panel.dart';

class PurchasePage extends ConsumerStatefulWidget {
  const PurchasePage({super.key});

  @override
  ConsumerState<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends ConsumerState<PurchasePage> {
  final _searchCtrl = TextEditingController();
  bool _showCartOnCompact = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(purchaseCartProvider);

    Widget buildProductList({required bool compact}) => Column(
          children: [
            PageHeader(
              title: 'Pembelian Stok',
              subtitle: 'Catat barang masuk dari supplier',
              icon: Icons.local_shipping_rounded,
              actions: [
                ElevatedButton.icon(
                  onPressed: () => ProductFormDialog.show(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(compact ? 'Tambah' : 'PRODUK BARU'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),

            // Search Field
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 24, vertical: compact ? 8 : 16),
              color: AppTheme.surface,
              child: AppSearchField(
                controller: _searchCtrl,
                hintText: 'Cari produk untuk dibeli...',
                onChanged: (v) =>
                    ref.read(productSearchQueryProvider.notifier).set(v),
                onClear: () {
                  _searchCtrl.clear();
                  ref.read(productSearchQueryProvider.notifier).set('');
                },
              ),
            ),

            // Product List
            Expanded(
              child: _ProductPurchaseList(),
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
          child: const PurchaseCartPanel(),
        );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          if (!compact) {
            return Row(
              children: [
                Expanded(flex: 1, child: buildProductList(compact: false)),
                Expanded(flex: 1, child: buildCartPanel(compact: false)),
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
                      label: Text('Produk Pembelian'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text('Keranjang Stok (${cart.items.length})'),
                    ),
                  ],
                  selected: {_showCartOnCompact},
                  onSelectionChanged: (selection) {
                    setState(() => _showCartOnCompact = selection.first);
                  },
                ),
              ),
              Expanded(
                child: _showCartOnCompact
                    ? buildCartPanel(compact: true)
                    : buildProductList(compact: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductPurchaseList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(filteredProductsProvider);
    final isLoading = ref.watch(productsProvider).isLoading;

    if (isLoading) return const AppLoading();

    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Produk tidak ditemukan',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PurchaseProductTile(product: products[i]),
    );
  }
}

class _PurchaseProductTile extends ConsumerWidget {
  final Product product;
  const _PurchaseProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            ref.read(purchaseCartProvider.notifier).addProduct(product),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ProductImage(imagePath: product.imagePath),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                        'Stok: ${Formatters.decimal(product.stock)} ${product.baseUnit}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('MODAL SAAT INI',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold)),
                  Text(Formatters.currency(product.costPrice),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.info)),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(Icons.add_shopping_cart_rounded,
                  color: AppTheme.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
