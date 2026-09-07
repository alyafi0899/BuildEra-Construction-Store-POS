import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../providers/purchase_cart_provider.dart';
import '../../../products/providers/entity_provider.dart';
import '../../../products/models/supplier.dart';
import 'purchase_checkout_dialog.dart';

class PurchaseCartPanel extends ConsumerWidget {
  const PurchaseCartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseCartProvider);
    final suppliers = ref.watch(suppliersProvider).asData?.value ?? [];

    return Column(
      children: [
        // ── Header & Supplier Selection ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Daftar Belanja (Stok Masuk)', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                  ),
                  IconButton(
                    onPressed: () => ref.read(purchaseCartProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger, size: 20),
                    tooltip: 'Kosongkan Keranjang',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: state.supplierId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Supplier',
                        prefixIcon: Icon(Icons.business_rounded, size: 20),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Umum / Tanpa Supplier', style: TextStyle(fontStyle: FontStyle.italic))),
                        ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (id) {
                        final name = suppliers.firstWhere((s) => s.id == id, orElse: () => Supplier(id: '', name: '', createdAt: DateTime.now())).name;
                        ref.read(purchaseCartProvider.notifier).setSupplier(id, id == null ? null : name);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showQuickAddSupplier(context, ref),
                    icon: const Icon(Icons.add_circle_rounded, color: AppTheme.accent),
                    tooltip: 'Tambah Supplier Baru',
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Cart Items List ──────────────────────────────────────────────────
        Expanded(
          child: state.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded, size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 16),
                      Text('Belum ada barang dipilih', style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _PurchaseCartTile(item: state.items[i]),
                ),
        ),

        // ── Totals & Checkout ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            border: const Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              _totalRow('Subtotal', state.subtotal, isBold: false),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Biaya Kirim', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      initialValue: state.shippingFee == 0 ? '' : Formatters.decimal(state.shippingFee),
                      onChanged: (v) => ref.read(purchaseCartProvider.notifier).setShippingFee(Formatters.parsePrice(v)),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: 'Rp ',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _totalRow('TOTAL PEMBELIAN', state.total, isBold: true, color: AppTheme.accent, size: 20),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isEmpty ? null : () => PurchaseCheckoutDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('PROSES PEMBELIAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, double val, {bool isBold = false, Color? color, double size = 14}) {
    return Row(
      children: [
        Text(label, style: TextStyle(
          color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
          fontSize: size - 2,
        )),
        const Spacer(),
        Text(Formatters.currency(val), style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          fontSize: size,
        )),
      ],
    );
  }

  void _showQuickAddSupplier(BuildContext context, WidgetRef ref) {
    const uuid = Uuid();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Supplier Baru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Perusahaan/Sales *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Alamat', isDense: true),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = Supplier(
                  id: uuid.v4(),
                  name: nameCtrl.text.trim(), 
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                  createdAt: DateTime.now()
                );
                await ref.read(entityRepositoryProvider).saveSupplier(s);
                ref.read(purchaseCartProvider.notifier).setSupplier(s.id, s.name);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseCartTile extends ConsumerStatefulWidget {
  final PurchaseCartItem item;
  const _PurchaseCartTile({required this.item});

  @override
  ConsumerState<_PurchaseCartTile> createState() => _PurchaseCartTileState();
}

class _PurchaseCartTileState extends ConsumerState<_PurchaseCartTile> {
  late final TextEditingController _qtyCtrl, _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: Formatters.decimal(widget.item.quantity));
    _priceCtrl = TextEditingController(text: Formatters.decimal(widget.item.purchasePrice));
  }

  @override
  void didUpdateWidget(_PurchaseCartTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync Qty if changed from outside (e.g. clicking product list)
    if (oldWidget.item.quantity != widget.item.quantity) {
      final currentInput = Formatters.parseQuantity(_qtyCtrl.text);
      if (currentInput != widget.item.quantity) {
        _qtyCtrl.text = Formatters.decimal(widget.item.quantity);
      }
    }

    // Sync Price if changed from outside
    if (oldWidget.item.purchasePrice != widget.item.purchasePrice) {
      final currentInput = Formatters.parsePrice(_priceCtrl.text);
      if (currentInput != widget.item.purchasePrice) {
        _priceCtrl.text = Formatters.decimal(widget.item.purchasePrice);
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<ProductUnit>(
                      value: item.unit,
                      isDense: true,
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                      items: item.product.allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u.unitName))).toList(),
                      onChanged: (u) => ref.read(purchaseCartProvider.notifier).updateUnit(item.id, u!),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(purchaseCartProvider.notifier).removeItem(item.id),
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              // Qty
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QTY', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _qtyCtrl,
                      onChanged: (v) => ref.read(purchaseCartProvider.notifier).updateQuantity(item.id, Formatters.parseQuantity(v)),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Purchase Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HARGA BELI PER UNIT', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _priceCtrl,
                      onChanged: (v) => ref.read(purchaseCartProvider.notifier).updatePurchasePrice(item.id, Formatters.parsePrice(v)),
                      decoration: const InputDecoration(isDense: true, prefixText: 'Rp ', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Subtotal
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('SUBTOTAL', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
