import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';

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
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          color: AppTheme.surface,
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Inventori', style: Theme.of(context).textTheme.headlineLarge),
              Text('Monitor stok produk secara real-time', style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ]),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _tableHeader(context),
                  ...filtered.asMap().entries.map((e) => _InventoryRow(product: e.value, isEven: e.key.isEven)),
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
        _th('Sesuaikan Stok', flex: 2, align: TextAlign.center),
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
  final bool isEven;
  const _InventoryRow({required this.product, required this.isEven});

  @override
  ConsumerState<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends ConsumerState<_InventoryRow> {
  final _adjCtrl = TextEditingController();

  Future<void> _adjust(double delta) async {
    await ref.read(productsProvider.notifier).adjustStock(widget.product.id, delta);
    _adjCtrl.clear();
    if (mounted) showSuccess(context, 'Stok diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final Color statusColor = p.stock <= 0 ? AppTheme.danger : p.isLowStock ? AppTheme.warning : AppTheme.success;
    final String statusLabel = p.stock <= 0 ? 'Habis' : p.isLowStock ? 'Rendah' : 'Normal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:  widget.isEven ? AppTheme.card : AppTheme.surface,
        border: const Border(
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Text(p.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13))),
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
        Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 80,
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
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(_adjCtrl.text);
              if (v != null) _adjust(v);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Update'),
          ),
        ])),
      ]),
    );
  }
}
