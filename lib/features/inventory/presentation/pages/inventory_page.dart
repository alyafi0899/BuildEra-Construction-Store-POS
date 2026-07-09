import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/products/providers/product_provider.dart';
import 'package:buildera/features/inventory/providers/restock_provider.dart';
import 'package:buildera/features/inventory/models/restock_record.dart';
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
          const PageHeader(
            title: 'Inventori',
            subtitle: 'Monitor stok produk secara real-time',
            icon: Icons.warehouse_rounded,
          ),

          // ── Stats Summary ─────────────────────────────────────────────
          if (productsAsync.hasValue)
            _buildStatsHeader(productsAsync.value!),

          // ── Filters ──────────────────────────────────────────────
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
                  hintText: 'Cari produk...',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Stok Rendah'),
                selected: _lowOnly,
                onSelected: (v) => setState(() => _lowOnly = v),
                selectedColor: colorScheme.primary.withValues(alpha: 0.1),
                checkmarkColor: colorScheme.primary,
                side: BorderSide(color: _lowOnly ? colorScheme.primary : colorScheme.outline),
              ),
            ]),
          ),

          // ── Product Table Header ─────────────────────────────────────
          _buildTableHeader(context),

          // ── Product List ──────────────────────────────────────────────
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

                // Sort by stock ascending (priority: lowest stock first as requested)
                filtered.sort((a, b) => a.stock.compareTo(b.stock));

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Tidak ada data stok');
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _InventoryRow(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(List<Product> products) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSku = products.length;
    final lowStock = products.where((p) => p.isLowStock && p.stock > 0).length;
    final outOfStock = products.where((p) => p.stock <= 0).length;

    return Container(
      padding: const EdgeInsets.all(24),
      color: colorScheme.surface,
      child: Row(
        children: [
          Expanded(child: StatCard(label: 'Total SKU', value: totalSku.toString(), icon: Icons.inventory_2_rounded, accentColor: colorScheme.primary)),
          const SizedBox(width: 16),
          Expanded(child: StatCard(label: 'Stok Rendah', value: lowStock.toString(), icon: Icons.warning_amber_rounded, accentColor: const Color(0xFFF39C12))),
          const SizedBox(width: 16),
          Expanded(child: StatCard(label: 'Habis', value: outOfStock.toString(), icon: Icons.cancel_presentation_rounded, accentColor: colorScheme.error)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Satuan Dasar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Stok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          Expanded(flex: 1, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Aksi / Penyesuaian', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _InventoryRow extends ConsumerStatefulWidget {
  final Product product;
  const _InventoryRow({required this.product});

  @override
  ConsumerState<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends ConsumerState<_InventoryRow> {
  final _quickAddCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _submitQuickAdd() async {
    final qty = double.tryParse(_quickAddCtrl.text) ?? 0;
    if (qty <= 0) return;

    setState(() => _saving = true);
    try {
      await ref.read(productsActionProvider).adjustStock(widget.product.id, qty);
      _quickAddCtrl.clear();
      if (mounted) showSuccess(context, 'Stok ${widget.product.name} bertambah $qty');
    } catch (e) {
      if (mounted) showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final colorScheme = Theme.of(context).colorScheme;
    final isOut = p.stock <= 0;
    final isLow = p.isLowStock;
    final statusColor = isOut ? colorScheme.error : isLow ? const Color(0xFFF39C12) : const Color(0xFF2ECC71);
    final statusText = isOut ? 'Habis' : isLow ? 'Rendah' : 'Aman';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5))),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(),
        title: Row(
          children: [
            Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 2, child: Text(p.category, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)))),
            Expanded(flex: 1, child: Text(p.baseUnit, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)))),
            Expanded(flex: 1, child: Text(Formatters.decimal(p.stock), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Center(child: StatusChip(label: statusText.toUpperCase(), color: statusColor))),
            
            // Actions Column
            Expanded(flex: 2, child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. Restock Button
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => RestockDialog.show(context, p),
                    icon: const Icon(Icons.shopping_cart_rounded, size: 14),
                    label: const Text('Restock', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Quick Qty Input
                SizedBox(
                  width: 60,
                  height: 32,
                  child: TextField(
                    controller: _quickAddCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '+Qty',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 3. Confirm Quick Add
                IconButton(
                  onPressed: _saving ? null : _submitQuickAdd,
                  icon: _saving 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF2ECC71), size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )),
          ],
        ),
        children: [
          _buildRestockHistory(context, p),
        ],
      ),
    );
  }

  Widget _buildRestockHistory(BuildContext context, Product product) {
    final restocksAsync = ref.watch(restockHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('RIWAYAT RESTOCK PRODUK INI', 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 1)),
              const Spacer(),
              Text('Urut: Teranyar', style: TextStyle(fontSize: 9, color: colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 12),
          restocksAsync.when(
            data: (allRestocks) {
              final records = allRestocks.where((r) => r.productId == product.id).toList();
              if (records.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Belum ada data restock tercatat.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                );
              }

              return Column(
                children: records.map((r) => _RestockHistoryRow(record: r, product: product)).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Gagal memuat riwayat'),
          ),
        ],
      ),
    );
  }
}

class _RestockHistoryRow extends ConsumerWidget {
  final RestockRecord record;
  final Product product;
  const _RestockHistoryRow({required this.record, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${Formatters.decimal(record.quantityAdded)} ${record.unitName}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('•  ${record.supplierName ?? 'Supplier Umum'}', 
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                ),
                Text(Formatters.dateTime(record.createdAt), 
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(record.supplierPrice + record.shippingCost), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Modal: ${Formatters.currency(record.totalCostPerUnit)} / unit', 
                style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => RestockDialog.show(context, product, record: record),
            icon: Icon(Icons.edit_rounded, size: 16, color: colorScheme.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit Record',
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context, 
                title: 'Hapus Riwayat', 
                content: 'Data ini akan dihapus and stok akan dikurangi kembali. Lanjutkan?',
                confirmColor: colorScheme.error
              );
              if (ok) {
                await ref.read(restockNotifierProvider.notifier).deleteRestock(record);
                if (context.mounted) showSuccess(context, 'Riwayat dihapus');
              }
            },
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: colorScheme.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Hapus Record',
          ),
        ],
      ),
    );
  }
}
