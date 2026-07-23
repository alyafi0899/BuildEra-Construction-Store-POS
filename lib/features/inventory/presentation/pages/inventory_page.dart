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

          // Stats Row
          productsAsync.when(
            data: (products) {
              final total = products.length;
              final low = products.where((p) => p.isLowStock).length;
              final out = products.where((p) => p.stock <= 0).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 90,
                child: Row(
                  children: [
                    _invStat('Total SKU', total.toString(), AppTheme.primary),
                    const SizedBox(width: 8),
                    _invStat('Stok Rendah', low.toString(), AppTheme.warning),
                    const SizedBox(width: 8),
                    _invStat('Habis', out.toString(), AppTheme.danger),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 90),
            error: (_, __) => const SizedBox(),
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

  Widget _invStat(String label, String val, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(12),
        color: color.withValues(alpha: 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends ConsumerStatefulWidget {
  final Product product;
  const _InventoryCard({required this.product});

  @override
  ConsumerState<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends ConsumerState<_InventoryCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isLow = product.isLowStock;
    final isOut = product.stock <= 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showHistory = !_showHistory),
            child: Row(
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
                const SizedBox(width: 8),
                Icon(_showHistory ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textMuted),
              ],
            ),
          ),
          if (_showHistory) _buildHistory(context, ref, product),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showQuickAdjust(context, ref, product),
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

  Widget _buildHistory(BuildContext context, WidgetRef ref, Product p) {
    final historyAsync = ref.watch(restockHistoryProvider);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: historyAsync.when(
        data: (list) {
          final prodRecords = list.where((r) => r.productId == p.id).toList();
          if (prodRecords.isEmpty) return const Text('Belum ada riwayat restock', style: TextStyle(fontSize: 11, color: AppTheme.textMuted));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RIWAYAT TERBARU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              ...prodRecords.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(Formatters.date(r.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('+${Formatters.decimal(r.quantityAdded)}', style: const TextStyle(fontSize: 11, color: AppTheme.success)),
                    const Spacer(),
                    Text(Formatters.currency(r.totalCostPerUnit), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              )),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  void _showQuickAdjust(BuildContext context, WidgetRef ref, Product product) {
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
