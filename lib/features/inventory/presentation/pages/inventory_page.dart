import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/products/providers/product_provider.dart';
import 'package:buildera/shared/models/product.dart';
import '../widgets/restock_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  bool _lowOnly = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          PageHeader(
            title: 'Manajemen Inventori',
            subtitle: 'Pantau stok dan riwayat masuk barang',
            icon: Icons.warehouse_rounded,
          ),

          // Overview Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: colorScheme.surface,
            child: productsAsync.when(
              data: (list) {
                final lowStock = list.where((p) => p.isLowStock && p.stock > 0).length;
                final outOfStock = list.where((p) => p.stock <= 0).length;
                return Row(
                  children: [
                    Expanded(child: StatCard(label: 'Stok Rendah', value: lowStock.toString(), icon: Icons.warning_amber_rounded, accentColor: colorScheme.secondary)),
                    const SizedBox(width: 16),
                    Expanded(child: StatCard(label: 'Habis', value: outOfStock.toString(), icon: Icons.error_outline_rounded, accentColor: colorScheme.error)),
                  ],
                );
              },
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(children: [
              SizedBox(
                width: 300,
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Cari nama atau kategori...',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Hanya Stok Menipis/Habis'),
                selected: _lowOnly,
                onSelected: (v) => setState(() => _lowOnly = v),
                selectedColor: colorScheme.secondary.withValues(alpha: 0.2),
                checkmarkColor: colorScheme.secondary,
                side: BorderSide(color: _lowOnly ? colorScheme.secondary : colorScheme.outline),
              ),
            ]),
          ),

          // Product List
          Expanded(
            child: productsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = products.where((p) {
                  final matchSearch = p.name.toLowerCase().contains(_search.toLowerCase()) || 
                                     p.category.toLowerCase().contains(_search.toLowerCase());
                  final matchStock = !_lowOnly || p.isLowStock;
                  return matchSearch && matchStock;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Tidak ada data stok');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _InventoryItemRow(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryItemRow extends StatefulWidget {
  final Product product;
  const _InventoryItemRow({required this.product});

  @override
  State<_InventoryItemRow> createState() => _InventoryItemRowState();
}

class _InventoryItemRowState extends State<_InventoryItemRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final colorScheme = Theme.of(context).colorScheme;
    final Color statusColor = p.stock <= 0 ? colorScheme.error : p.isLowStock ? colorScheme.secondary : const Color(0xFF2ECC71);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _expanded ? colorScheme.primary : colorScheme.outline),
      ),
      child: Material(
        color: _expanded ? colorScheme.primary.withValues(alpha: 0.05) : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              onTap: () => setState(() => _expanded = !_expanded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.inventory_2_rounded, color: colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p.category, style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${Formatters.decimal(p.stock)} ${p.baseUnit}', 
                        style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 16)),
                      Text(p.stock <= 0 ? 'HABIS' : p.isLowStock ? 'MENIPIS' : 'AMAN', 
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(indent: 20, endIndent: 20),
              _RestockDetailSection(product: p),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestockDetailSection extends ConsumerWidget {
  final Product product;
  const _RestockDetailSection({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _detailItem(context, 'Harga Modal', Formatters.currency(product.costPrice)),
              const SizedBox(width: 32),
              _detailItem(context, 'Harga Jual', Formatters.currency(product.basePrice)),
              const Spacer(),
              _QuickAddStockField(product: product),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => RestockDialog.show(context, product),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('RESTOCK RINCIAN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _QuickAddStockField extends ConsumerStatefulWidget {
  final Product product;
  const _QuickAddStockField({required this.product});

  @override
  ConsumerState<_QuickAddStockField> createState() => _QuickAddStockFieldState();
}

class _QuickAddStockFieldState extends ConsumerState<_QuickAddStockField> {
  final _qtyCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    setState(() => _saving = true);
    try {
      await ref.read(productsActionProvider).adjustStock(widget.product.id, qty);
      _qtyCtrl.clear();
      if (mounted) showSuccess(context, 'Stok ${widget.product.name} bertambah $qty');
    } catch (e) {
      if (mounted) showError(context, 'Gagal update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Qty +',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _saving ? null : _submit,
          icon: _saving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
