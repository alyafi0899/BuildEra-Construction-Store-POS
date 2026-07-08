import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/models/product_financials.dart';
import '../../../products/providers/product_provider.dart';
import '../../../products/providers/entity_provider.dart';
import '../../../products/models/supplier.dart';
import '../../../products/models/shipping_service.dart';
import '../../models/restock_record.dart';
import '../../providers/restock_provider.dart';

final _uuid = const Uuid();

class RestockDialog extends ConsumerStatefulWidget {
  final Product product;
  final RestockRecord? record;
  const RestockDialog({super.key, required this.product, this.record});

  static Future<void> show(BuildContext context, Product product, {RestockRecord? record}) {
    return showDialog(
      context:            context,
      barrierDismissible: false,
      builder:            (_) => RestockDialog(product: product, record: record),
    );
  }

  @override
  ConsumerState<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends ConsumerState<RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qty, _supplierPrice, _supplierShippingCost, _totalCostPerUnit, _basePrice, _supplierName, _shippingServiceName, _notes;
  
  bool _isManualCost = false;
  PaymentStatus _supplierPaymentStatus = PaymentStatus.paid;
  PaymentStatus _shippingPaymentStatus = PaymentStatus.paid;
  
  String? _selectedSupplierId;
  String? _selectedShippingId;
  late ProductUnit _selectedUnit;
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final r = widget.record;
    
    _qty = TextEditingController(text: r != null ? r.quantityAdded.toStringAsFixed(r.quantityAdded % 1 == 0 ? 0 : 2) : '1');
    _supplierPrice = TextEditingController(text: r != null ? r.supplierPrice.toStringAsFixed(0) : '');
    _supplierShippingCost = TextEditingController(text: r != null ? r.shippingCost.toStringAsFixed(0) : '');
    _totalCostPerUnit = TextEditingController(text: r != null ? r.totalCostPerUnit.toStringAsFixed(0) : p.costPrice.toStringAsFixed(0));
    _basePrice = TextEditingController(text: r != null ? r.sellingPrice.toStringAsFixed(0) : p.basePrice.toStringAsFixed(0));
    _supplierName = TextEditingController();
    _shippingServiceName = TextEditingController();
    _notes = TextEditingController(text: r?.notes ?? '');
    
    _selectedUnit = r != null 
        ? (p.allUnits.firstWhereOrNull((u) => u.unitName == r.unitName) ?? p.allUnits.first)
        : p.allUnits.first;
    
    _isManualCost = r == null ? p.financials.isManualCost : (r.supplierPrice == 0 && r.shippingCost == 0);
    _supplierPaymentStatus = r?.supplierPaymentStatus ?? p.financials.supplierPaymentStatus;
    if (_supplierPaymentStatus == PaymentStatus.notApplicable) _supplierPaymentStatus = PaymentStatus.paid;
    
    _shippingPaymentStatus = r?.shippingPaymentStatus ?? p.financials.shippingPaymentStatus;
    if (_shippingPaymentStatus == PaymentStatus.notApplicable) _shippingPaymentStatus = PaymentStatus.paid;
    
    // Resolve entity IDs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sList = ref.read(suppliersProvider).asData?.value ?? [];
      final shList = ref.read(shippingServicesProvider).asData?.value ?? [];
      final sName = r?.supplierName ?? p.financials.supplierName;
      final shName = r?.shippingServiceName ?? p.financials.shippingServiceName;
      
      setState(() {
        if (sName != null) _selectedSupplierId = sList.firstWhereOrNull((s) => s.name == sName)?.id;
        if (shName != null) _selectedShippingId = shList.firstWhereOrNull((s) => s.name == shName)?.id;
      });
    });
  }

  @override
  void dispose() {
    _qty.dispose(); _supplierPrice.dispose(); _supplierShippingCost.dispose();
    _totalCostPerUnit.dispose(); _basePrice.dispose(); _supplierName.dispose();
    _shippingServiceName.dispose(); _notes.dispose();
    super.dispose();
  }

  void _calculateCost() {
    if (_isManualCost) return;
    final q = double.tryParse(_qty.text) ?? 0;
    final sp = double.tryParse(_supplierPrice.text) ?? 0;
    final sc = double.tryParse(_supplierShippingCost.text) ?? 0;
    if (q > 0) {
      final totalBaseQty = q * _selectedUnit.conversionRate;
      final cost = (sp + sc) / totalBaseQty;
      setState(() => _totalCostPerUnit.text = cost.toStringAsFixed(0));
    }
  }

  void _suggestPrice() {
    final cost = double.tryParse(_totalCostPerUnit.text) ?? 0;
    if (cost > 0) {
      final suggested = cost * 1.1; 
      setState(() => _basePrice.text = suggested.toStringAsFixed(0));
    }
  }

  double get _netProfit {
    final cost = double.tryParse(_totalCostPerUnit.text) ?? 0;
    final sell = double.tryParse(_basePrice.text) ?? 0;
    return sell - cost;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    try {
      final suppliers = ref.read(suppliersProvider).asData?.value ?? [];
      final shippings = ref.read(shippingServicesProvider).asData?.value ?? [];
      
      final supplierName = _selectedSupplierId != null 
          ? suppliers.firstWhereOrNull((s) => s.id == _selectedSupplierId)?.name 
          : _supplierName.text.trim().isEmpty ? null : _supplierName.text.trim();
          
      final shippingName = _selectedShippingId != null 
          ? shippings.firstWhereOrNull((s) => s.id == _selectedShippingId)?.name 
          : _shippingServiceName.text.trim().isEmpty ? null : _shippingServiceName.text.trim();

      final q = double.tryParse(_qty.text) ?? 0;
      final totalBaseQty = q * _selectedUnit.conversionRate;

      final record = RestockRecord(
        id: widget.record?.id ?? _uuid.v4(),
        productId: widget.product.id,
        productName: widget.product.name,
        quantityAdded: totalBaseQty,
        unitName: _selectedUnit.unitName,
        supplierPrice: double.tryParse(_supplierPrice.text) ?? 0,
        shippingCost: double.tryParse(_supplierShippingCost.text) ?? 0,
        totalCostPerUnit: double.tryParse(_totalCostPerUnit.text) ?? 0,
        sellingPrice: double.tryParse(_basePrice.text) ?? 0,
        supplierName: supplierName,
        supplierPaymentStatus: _supplierPaymentStatus,
        shippingServiceName: shippingName,
        shippingPaymentStatus: _shippingPaymentStatus,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      if (widget.record != null) {
        await ref.read(restockNotifierProvider.notifier).updateRestock(widget.record!, record);
      } else {
        await ref.read(restockNotifierProvider.notifier).addRestock(record);
      }
      
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, widget.record == null ? 'Stok berhasil ditambah' : 'Data restock diperbarui');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 740,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colorScheme.outline))),
              child: Row(children: [
                Icon(Icons.add_shopping_cart_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Text(widget.record == null ? 'Restock Barang' : 'Edit Data Restock', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ]),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _productSummary(context),
                      const SizedBox(height: 24),

                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _qty,
                            decoration: const InputDecoration(labelText: 'Jumlah Tambahan *'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _calculateCost(),
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: DropdownButtonFormField<ProductUnit>(
                              value: _selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Satuan Pembelian', isDense: true),
                              dropdownColor: colorScheme.surface,
                              items: widget.product.allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u.unitName))).toList(),
                              onChanged: (v) {
                                setState(() => _selectedUnit = v!);
                                _calculateCost();
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                      ]),
                      const SizedBox(height: 24),

                      _sectionLabel(context, 'Biaya & Supplier'),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Metode Perhitungan Modal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Pilih Otomatis jika ingin menghitung modal dari total beli + ongkir', 
                                        style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      Text('Otomatis', style: TextStyle(fontSize: 11, fontWeight: !_isManualCost ? FontWeight.bold : FontWeight.normal, color: !_isManualCost ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4))),
                                      Switch(
                                        value: _isManualCost,
                                        onChanged: (v) => setState(() => _isManualCost = v),
                                      ),
                                      Text('Manual', style: TextStyle(fontSize: 11, fontWeight: _isManualCost ? FontWeight.bold : FontWeight.normal, color: _isManualCost ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            
                            if (!_isManualCost) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _supplierPrice,
                                      decoration: const InputDecoration(labelText: 'Harga Total Supplier (Rp)', prefixText: 'Rp ', isDense: true),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _calculateCost(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _supplierShippingCost,
                                      decoration: const InputDecoration(labelText: 'Total Ongkos Kirim (Rp)', prefixText: 'Rp ', isDense: true),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => _calculateCost(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalCostPerUnit,
                                    readOnly: !_isManualCost,
                                    decoration: InputDecoration(
                                      labelText: 'Total Modal per Unit (Rp) *',
                                      prefixText: 'Rp ',
                                      fillColor: !_isManualCost ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : null,
                                      filled: !_isManualCost,
                                      helperText: !_isManualCost ? 'Dihitung otomatis: (Beli+Ongkir)/Qty' : 'Input harga modal akhir per unit',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) => double.tryParse(v ?? '') == null ? 'Wajib diisi' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _basePrice,
                                    decoration: InputDecoration(
                                      labelText: 'Harga Jual per Unit (Rp) *',
                                      prefixText: 'Rp ',
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF1C40F), size: 20),
                                        tooltip: 'Saran Harga (+10%)',
                                        onPressed: _suggestPrice,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      final sell = double.tryParse(v ?? '') ?? 0;
                                      final cost = double.tryParse(_totalCostPerUnit.text) ?? 0;
                                      if (sell <= 0) return 'Wajib diisi';
                                      if (sell < cost) return 'Harga jual di bawah modal';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _netProfit >= 0 ? const Color(0xFF2ECC71).withValues(alpha: 0.1) : colorScheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (_netProfit >= 0 ? const Color(0xFF2ECC71) : colorScheme.error).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                                    color: _netProfit >= 0 ? const Color(0xFF2ECC71) : colorScheme.error, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Estimasi Profit Bersih:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(Formatters.currency(_netProfit), 
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _netProfit >= 0 ? const Color(0xFF2ECC71) : colorScheme.error)),
                                  Text(' / unit', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Informasi Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () => _showQuickAddSupplier(context),
                                      icon: Icon(Icons.add_business_rounded, size: 16, color: colorScheme.primary),
                                      tooltip: 'Supplier Baru',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ref.watch(suppliersProvider).when(
                                  data: (list) => SizedBox(
                                    height: 48,
                                    child: DropdownButtonFormField<String?>(
                                      value: _selectedSupplierId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Pilih Supplier', isDense: true),
                                      dropdownColor: colorScheme.surface,
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('Input Manual / Umum', style: TextStyle(fontSize: 12))),
                                        ...list.map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12))),
                                              IconButton(
                                                icon: Icon(Icons.edit_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                                                onPressed: () => _showQuickAddSupplier(context, supplier: s),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline_rounded, size: 14, color: colorScheme.error),
                                                onPressed: () async {
                                                  final ok = await showConfirmDialog(context, title: 'Hapus Supplier', content: 'Yakin hapus supplier "${s.name}"?');
                                                  if (ok) {
                                                    await ref.read(entityRepositoryProvider).deleteSupplier(s.id);
                                                    setState(() => _selectedSupplierId = null);
                                                  }
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        )),
                                      ],
                                      onChanged: (v) => setState(() => _selectedSupplierId = v),
                                    ),
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, __) => const Text('Error memuat supplier'),
                                ),
                                if (_selectedSupplierId == null) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(controller: _supplierName, decoration: const InputDecoration(labelText: 'Nama Supplier', isDense: true)),
                                ],
                                const SizedBox(height: 12),
                                _statusSelector(context, 'Status Bayar Supplier', _supplierPaymentStatus, (v) => setState(() => _supplierPaymentStatus = v!)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Jasa Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () => _showQuickAddShipping(context),
                                      icon: Icon(Icons.add_road_rounded, size: 16, color: colorScheme.primary),
                                      tooltip: 'Ekspedisi Baru',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ref.watch(shippingServicesProvider).when(
                                  data: (list) => SizedBox(
                                    height: 48,
                                    child: DropdownButtonFormField<String?>(
                                      value: _selectedShippingId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Pilih Ekspedisi', isDense: true),
                                      dropdownColor: colorScheme.surface,
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('Input Manual / Umum', style: TextStyle(fontSize: 12))),
                                        ...list.map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12))),
                                              IconButton(
                                                icon: Icon(Icons.edit_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                                                onPressed: () => _showQuickAddShipping(context, shipping: s),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline_rounded, size: 14, color: colorScheme.error),
                                                onPressed: () async {
                                                  final ok = await showConfirmDialog(context, title: 'Hapus Ekspedisi', content: 'Yakin hapus ekspedisi "${s.name}"?');
                                                  if (ok) {
                                                    await ref.read(entityRepositoryProvider).deleteShippingService(s.id);
                                                    setState(() => _selectedShippingId = null);
                                                  }
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        )),
                                      ],
                                      onChanged: (v) => setState(() => _selectedShippingId = v),
                                    ),
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, __) => const Text('Error memuat ekspedisi'),
                                ),
                                if (_selectedShippingId == null) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(controller: _shippingServiceName, decoration: const InputDecoration(labelText: 'Nama Ekspedisi', isDense: true)),
                                ],
                                const SizedBox(height: 12),
                                _statusSelector(context, 'Status Bayar Ongkir', _shippingPaymentStatus, (v) => setState(() => _shippingPaymentStatus = v!)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Catatan Restock (Opsional)'), maxLines: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.outline))),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : Text(widget.record == null ? 'TAMBAH STOK' : 'SIMPAN PERUBAHAN'),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('Stok Saat Ini: ${Formatters.decimal(widget.product.stock)} ${widget.product.baseUnit}', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Row(children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _statusSelector(BuildContext context, String label, PaymentStatus current, ValueChanged<PaymentStatus?> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: DropdownButtonFormField<PaymentStatus>(
            value: current,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            dropdownColor: colorScheme.surface,
            items: [PaymentStatus.paid, PaymentStatus.unpaid].map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showQuickAddSupplier(BuildContext context, {Supplier? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name);
    final phoneCtrl = TextEditingController(text: supplier?.phone);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(supplier == null ? 'Supplier Baru' : 'Edit Supplier'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Supplier')),
        const SizedBox(height: 16),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor Telepon')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SIMPAN')),
      ],
    ));
    if (ok == true && nameCtrl.text.isNotEmpty) {
      final s = supplier?.copyWith(name: nameCtrl.text, phone: phoneCtrl.text) ?? Supplier(id: _uuid.v4(), name: nameCtrl.text, phone: phoneCtrl.text, createdAt: DateTime.now());
      await ref.read(entityRepositoryProvider).saveSupplier(s);
      setState(() => _selectedSupplierId = s.id);
    }
  }

  void _showQuickAddShipping(BuildContext context, {ShippingService? shipping}) async {
    final nameCtrl = TextEditingController(text: shipping?.name);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(shipping == null ? 'Ekspedisi Baru' : 'Edit Ekspedisi'),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Ekspedisi')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SIMPAN')),
      ],
    ));
    if (ok == true && nameCtrl.text.isNotEmpty) {
      final s = shipping?.copyWith(name: nameCtrl.text) ?? ShippingService(id: _uuid.v4(), name: nameCtrl.text, createdAt: DateTime.now());
      await ref.read(entityRepositoryProvider).saveShippingService(s);
      setState(() => _selectedShippingId = s.id);
    }
  }
}
