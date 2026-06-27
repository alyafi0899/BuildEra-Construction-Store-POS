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
  final ScrollController _scrollController = ScrollController();
  String _search = '';
  bool _lowOnly = false;

  @override
  void dispose() { 
    _searchCtrl.dispose(); 
    _scrollController.dispose();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header
           PageHeader(
          title: 'Inventori',
          subtitle: 'Monitor stok produk secara real-time',
          icon: Icons.warehouse_rounded,
        ),

        // Stats row
        productsAsync.when(
          loading: () => const SizedBox(height: 100),
          error:   (_, __) => const SizedBox(),
          data: (products) {
            final lowStock  = products.where((p) => p.isLowStock).length;
            final totalSKU  = products.length;
            final outOfStock = products.where((p) => p.stock <= 0).length;
            return Container(
              padding: const EdgeInsets.all(20),
              color: AppTheme.surface,
              child: Row(children: [
                Expanded(child: StatCard(label: 'Total SKU',     value: totalSKU.toString(),  icon: Icons.inventory_2_rounded)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(label: 'Stok Rendah',  value: lowStock.toString(),   icon: Icons.warning_amber_rounded, accentColor: AppTheme.warning)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(label: 'Habis',        value: outOfStock.toString(), icon: Icons.remove_shopping_cart_rounded, accentColor: AppTheme.danger)),
              ]),
            );
          },
        ),

        // Filters
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AppTheme.surface,
          child: Row(children: [
            SizedBox(
              width: 280,
              child: AppSearchField(
                controller: _searchCtrl,
                hintText: 'Cari produk...',
                onChanged: (v) => setState(() => _search = v),
                onClear: () => setState(() { _search = ''; _searchCtrl.clear(); }),
              ),
            ),
            const SizedBox(width: 16),
            FilterChip(
              label:    const Text('Stok Rendah'),
              selected: _lowOnly,
              onSelected: (v) => setState(() => _lowOnly = v),
              selectedColor:    AppTheme.warning.withValues(alpha: 0.2),
              checkmarkColor:   AppTheme.warning,
              side: BorderSide(color: _lowOnly ? AppTheme.warning : AppTheme.border),
            ),
          ]),
        ),

        // Table
        Expanded(child: productsAsync.when(
          loading: () => const AppLoading(),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data: (products) {
            final filtered = products.where((p) {
              final matchSearch = _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase());
              final matchLow    = !_lowOnly || p.isLowStock;
              return matchSearch && matchLow;
            }).toList()
              ..sort((a, b) => a.stock.compareTo(b.stock));

            if (filtered.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Tidak ada data inventori');

            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _tableHeader(context),
                  ...filtered.map((p) => _InventoryRow(key: ValueKey('inv_${p.id}'), product: p)),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _tableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _th('Produk',     flex: 3),
        _th('Kategori',   flex: 2),
        _th('Satuan Dasar', flex: 1),
        _th('Stok',       flex: 1, align: TextAlign.right),
        _th('Status',     flex: 1, align: TextAlign.center),
        _th('Aksi / Penyesuaian', flex: 3, align: TextAlign.center),
      ]),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _InventoryRow extends ConsumerStatefulWidget {
  final Product product;
  const _InventoryRow({super.key, required this.product});

  @override
  ConsumerState<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends ConsumerState<_InventoryRow> {
  final _adjCtrl = TextEditingController();
  bool _expanded = false;

  Future<void> _adjust(double delta) async {
    await ref.read(productsActionProvider).adjustStock(widget.product.id, delta);
    _adjCtrl.clear();
    if (mounted) showSuccess(context, 'Stok diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final Color statusColor = p.stock <= 0 ? AppTheme.danger : p.isLowStock ? AppTheme.warning : AppTheme.success;
    final String statusLabel = p.stock <= 0 ? 'Habis' : p.isLowStock ? 'Rendah' : 'Normal';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:  _expanded ? AppTheme.accent.withValues(alpha: 0.05) : AppTheme.surface,
            border: const Border(
              left: BorderSide(color: AppTheme.border),
              right: BorderSide(color: AppTheme.border),
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, 
                    size: 20, color: AppTheme.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13))),
              ],
            )),
            Expanded(flex: 2, child: Text(p.category, style: Theme.of(context).textTheme.bodyMedium)),
            Expanded(flex: 1, child: Text(p.baseUnit, style: Theme.of(context).textTheme.bodyMedium)),
            Expanded(flex: 1, child: Text(
              Formatters.decimal(p.stock),
              textAlign: TextAlign.right,
              style: TextStyle(
                color:      statusColor,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              ),
            )),
            Expanded(flex: 1, child: Center(child: StatusChip(label: statusLabel, color: statusColor))),
            Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: () => RestockDialog.show(context, p),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: const Text('Restock'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _adjCtrl,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '±Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  final v = double.tryParse(_adjCtrl.text);
                  if (v != null) _adjust(v);
                },
                icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ])),
          ]),
        ),
        if (_expanded) _buildHistorySection(p),
      ],
    );
  }

  Widget _buildHistorySection(Product p) {
    final historyAsync = ref.watch(restockHistoryProvider);
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 16, 16, 12),
            child: Text('RIWAYAT RESTOCK PRODUK INI', 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accent.withValues(alpha: 0.7), letterSpacing: 1.1)),
          ),
          historyAsync.when(
            data: (list) {
              final prodRecords = list.where((r) => r.productId == p.id).toList();
              if (prodRecords.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(56, 0, 16, 20),
                  child: Text('Belum ada data restock tercatat.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                );
              }

              return Column(
                children: [
                  ...prodRecords.map((r) => _RestockHistoryRow(record: r, product: p)),
                  const SizedBox(height: 12),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error'),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Formatters.dateTime(record.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              if (record.notes != null)
                Text(record.notes!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('+${Formatters.decimal(record.quantityAdded)} ${record.unitName}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 13)),
              Text('Modal: ${Formatters.currency(record.totalCostPerUnit)}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text('Jual: ${Formatters.currency(record.sellingPrice)}', style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (record.supplierName != null) _miniBadge(Icons.business_rounded, record.supplierName!, record.supplierPaymentStatus),
              if (record.shippingServiceName != null) _miniBadge(Icons.local_shipping_rounded, record.shippingServiceName!, record.shippingPaymentStatus),
            ]),
          ),
          // Calculations
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Net Beli: ${Formatters.currency(record.supplierPrice)}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text('Ongkir: ${Formatters.currency(record.shippingCost)}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ]),
          ),
          const SizedBox(width: 16),
          // Actions
          IconButton(
            onPressed: () => RestockDialog.show(context, product, record: record),
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context, 
                title: 'Hapus Riwayat Restock', 
                content: 'Yakin hapus data ini? Stok akan dikurangi otomatis sesuai jumlah batch ini.');
              if (ok) {
                await ref.read(restockNotifierProvider.notifier).deleteRestock(record);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label, PaymentStatus status) {
    final color = status == PaymentStatus.paid ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
