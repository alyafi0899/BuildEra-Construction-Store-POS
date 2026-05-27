// lib/features/inventory/presentation/pages/inventory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_provider.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'Semua';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(allProductsProvider);

    final totalItems   = products.length;
    final lowStock     = products.where((p) => p.isLowStock && !p.isOutOfStock).length;
    final outOfStock   = products.where((p) => p.isOutOfStock).length;
    final healthy      = totalItems - lowStock - outOfStock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Manajemen Inventori',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${products.length} produk · stok real-time',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
        ),

        // Stats row
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(child: StatCard(title: 'Total Produk',  value: '$totalItems', icon: Icons.inventory_2_rounded)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Stok Normal',   value: '$healthy',   icon: Icons.check_circle_rounded,   iconColor: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Stok Rendah',   value: '$lowStock',  icon: Icons.warning_rounded,         iconColor: AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Stok Habis',    value: '$outOfStock',icon: Icons.error_rounded,           iconColor: AppColors.error)),
          ]),
        ),

        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: SearchField(
                controller: _searchCtrl,
                hintText: 'Cari produk...',
                onChanged: (_) => setState(() {}),
                onClear: () => setState(() {}),
              ),
            ),
            ...['Semua', 'Normal', 'Stok Rendah', 'Habis'].map((s) {
              final isSelected = _filterStatus == s;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(s, style: TextStyle(fontSize: 12,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filterStatus = s),
                  backgroundColor: AppColors.surfaceVariant,
                  selectedColor: AppColors.primaryContainer,
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ]),
        ),

        // Table
        Expanded(
          child: Builder(builder: (_) {
            var filtered = products;
            final q = _searchCtrl.text.toLowerCase();
            if (q.isNotEmpty) filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
            switch (_filterStatus) {
              case 'Stok Rendah': filtered = filtered.where((p) => p.isLowStock && !p.isOutOfStock).toList(); break;
              case 'Habis':       filtered = filtered.where((p) => p.isOutOfStock).toList(); break;
              case 'Normal':      filtered = filtered.where((p) => !p.isLowStock).toList(); break;
            }

            if (filtered.isEmpty) {
              return const EmptyState(icon: Icons.warehouse_rounded, title: 'Tidak ada produk ditemukan');
            }
            return _InventoryTable(products: filtered);
          }),
        ),
      ],
    );
  }
}

// ─── TABLE ────────────────────────────────────────────────────────────────────

class _InventoryTable extends StatelessWidget {
  final List<ProductEntity> products;
  const _InventoryTable({required this.products});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(children: [
              Expanded(flex: 4, child: _H('Produk')),
              Expanded(flex: 2, child: _H('Kategori')),
              Expanded(flex: 2, child: _H('Satuan Dasar')),
              Expanded(flex: 2, child: _H('Stok')),
              Expanded(flex: 2, child: _H('Nilai Stok')),
              Expanded(flex: 2, child: _H('Status')),
              SizedBox(width: 80, child: _H('Aksi')),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) => _InventoryRow(product: products[i])
                  .animate(delay: Duration(milliseconds: 20 * i)).fadeIn(duration: 200.ms),
            ),
          ),
        ]),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// ─── ROW ─────────────────────────────────────────────────────────────────────

class _InventoryRow extends ConsumerStatefulWidget {
  final ProductEntity product;
  const _InventoryRow({required this.product});
  @override ConsumerState<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends ConsumerState<_InventoryRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final stockValue = p.stockQuantity * p.basePrice;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_)  => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hov ? AppColors.surfaceVariant.withValues(alpha: 0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Product
          Expanded(flex: 4, child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: p.isOutOfStock ? AppColors.errorContainer
                    : p.isLowStock   ? AppColors.warningContainer
                    : AppColors.successContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.construction_rounded,
                color: p.isOutOfStock ? AppColors.error
                    : p.isLowStock   ? AppColors.warning
                    : AppColors.success,
                size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(p.name,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 2, child: Text(p.category,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(p.baseUnit,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(
            AppFormatters.formatQuantity(p.stockQuantity),
            style: TextStyle(
              color: p.isOutOfStock ? AppColors.error : p.isLowStock ? AppColors.warning : AppColors.textPrimary,
              fontWeight: FontWeight.w700, fontSize: 14),
          )),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(stockValue),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Expanded(flex: 2, child: p.isOutOfStock ? StatusBadge.outOfStock()
              : p.isLowStock ? StatusBadge.lowStock() : StatusBadge.inStock()),
          SizedBox(width: 80, child: IconButton(
            onPressed: () => showDialog(context: context, builder: (_) => _StockAdjustDialog(product: p)),
            icon: const Icon(Icons.tune_rounded, size: 16),
            color: AppColors.primary, tooltip: 'Sesuaikan Stok',
          )),
        ]),
      ),
    );
  }
}

// ─── STOCK ADJUST DIALOG ─────────────────────────────────────────────────────

class _StockAdjustDialog extends ConsumerStatefulWidget {
  final ProductEntity product;
  const _StockAdjustDialog({required this.product});
  @override ConsumerState<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<_StockAdjustDialog> {
  final _qtyCtrl = TextEditingController();
  String _type = 'tambah';
  bool _saving = false;

  @override
  void dispose() { _qtyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final newStock = _type == 'tambah'
        ? p.stockQuantity + qty
        : (p.stockQuantity - qty).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text('Sesuaikan Stok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Stok saat ini: ${AppFormatters.formatQuantity(p.stockQuantity)} ${p.baseUnit}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // Type selector
          Row(children: [
            Expanded(child: _typeBtn('tambah', 'Tambah Stok',   Icons.add_rounded,    AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _typeBtn('kurang', 'Kurangi Stok',  Icons.remove_rounded, AppColors.error)),
          ]),
          const SizedBox(height: 16),

          // Qty input
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
            decoration: InputDecoration(labelText: 'Jumlah', suffixText: p.baseUnit),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Preview
          if (qty > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Stok setelah penyesuaian',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('${AppFormatters.formatQuantity(newStock)} ${p.baseUnit}',
                    style: TextStyle(
                      color: newStock <= 0 ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton.icon(
          onPressed: _saving || qty <= 0 ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 16),
          label: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _typeBtn(String type, String label, IconData icon, Color color) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    final adjustment = _type == 'tambah' ? qty : -qty;
    final success = await ref.read(productNotifierProvider.notifier).adjustStock(widget.product.id!, adjustment);
    setState(() => _saving = false);
    if (mounted) {
      Navigator.pop(context);
      if (success) {
        showSuccessSnackbar(context, 'Stok ${widget.product.name} berhasil disesuaikan');
      } else {
        showErrorSnackbar(context, 'Gagal menyesuaikan stok');
      }
    }
  }
}
