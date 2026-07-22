import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';
import '../../../products/models/product_financials.dart';
import '../../models/restock_record.dart';
import '../../providers/restock_provider.dart';
import '../widgets/restock_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _lowOnly = false;

  @override
  void dispose() { 
    _searchCtrl.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          const PageHeader(
            title: 'Stok Barang',
            subtitle: 'Monitor ketersediaan inventori',
            icon: Icons.warehouse_rounded,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Cari barang...',
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Stok Rendah'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                      selectedColor: AppTheme.danger.withValues(alpha: 0.1),
                      checkmarkColor: AppTheme.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: productsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = products.where((p) {
                  final matchSearch = _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase());
                  final matchLow = !_lowOnly || p.isLowStock;
                  return matchSearch && matchLow;
                }).toList()..sort((a, b) => a.stock.compareTo(b.stock));

                if (filtered.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Barang tidak ditemukan');

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _InventoryCard(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  final Product product;
  const _InventoryCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLow = product.isLowStock;
    final isOut = product.stock <= 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(product.category, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.decimal(product.stock), 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: isOut ? AppTheme.danger : (isLow ? AppTheme.warning : AppTheme.success)
                    )),
                  Text(product.baseUnit, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showQuickAdjust(context, ref),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Penyesuaian'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => RestockDialog.show(context, product),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Restock'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuickAdjust(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sesuaikan Stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Perubahan Qty',
                hintText: 'Contoh: -5 atau 10',
                helperText: 'Gunakan tanda (-) untuk mengurangi stok',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                await ref.read(productsActionProvider).adjustStock(product.id, val);
                if (context.mounted) {
                  Navigator.pop(context);
                  showSuccess(context, 'Stok diperbarui');
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
