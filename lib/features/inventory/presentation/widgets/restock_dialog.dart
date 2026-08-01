import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
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

final _uuid = Uuid();

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
  late List<_UnitEntry> _units;
  
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

    _units = p.units.map((u) => _UnitEntry.fromUnit(u)).toList();
    
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
    _qty.dispose();
    _supplierPrice.dispose();
    _supplierShippingCost.dispose();
    _totalCostPerUnit.dispose();
    _basePrice.dispose();
    _supplierName.dispose();
    _shippingServiceName.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _calculateCost() {
    if (_isManualCost) return;
    
    final q = Formatters.parseDecimal(_qty.text);
    final sp = Formatters.parseDecimal(_supplierPrice.text);
    final sc = Formatters.parseDecimal(_supplierShippingCost.text);
    
    if (q > 0) {
      final totalBaseQty = q * _selectedUnit.conversionRate;
      final cost = (sp + sc) / totalBaseQty;
      setState(() {
        _totalCostPerUnit.text = cost.toStringAsFixed(0);
      });
    }
  }

  void _suggestPrice() {
    final cost = Formatters.parseDecimal(_totalCostPerUnit.text);
    if (cost > 0) {
      final suggested = cost * 1.1; // +10%
      setState(() {
        _basePrice.text = suggested.toStringAsFixed(0);
      });
    }
  }

  double get _netProfit {
    final cost = Formatters.parseDecimal(_totalCostPerUnit.text);
    final sell = Formatters.parseDecimal(_basePrice.text);
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

      final totalBaseQty = Formatters.parseDecimal(_qty.text) * _selectedUnit.conversionRate;

      final record = RestockRecord(
        id: widget.record?.id ?? const Uuid().v4(),
        productId: widget.product.id,
        productName: widget.product.name,
        quantityAdded: totalBaseQty,
        unitName: _selectedUnit.unitName,
        supplierPrice: Formatters.parseDecimal(_supplierPrice.text),
        shippingCost: Formatters.parseDecimal(_supplierShippingCost.text),
        totalCostPerUnit: Formatters.parseDecimal(_totalCostPerUnit.text),
        sellingPrice: Formatters.parseDecimal(_basePrice.text),
        supplierName: supplierName,
        supplierPaymentStatus: _supplierPaymentStatus,
        shippingServiceName: shippingName,
        shippingPaymentStatus: _shippingPaymentStatus,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      // Save valid units
      final validUnits = _units.where((u) => u.unitName.trim().isNotEmpty).map((u) => u.toUnit(widget.product.id)).toList();
      final prodRepo = ref.read(productRepositoryProvider);
      final products = await prodRepo.getAllProducts();
      final p = products.firstWhere((p) => p.id == widget.product.id);
      
      // Update product units first
      await prodRepo.saveProduct(p.copyWith(units: validUnits), validUnits);

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

  void _addUnit() {
    setState(() => _units.add(_UnitEntry(id: _uuid.v4(), productId: widget.product.id)));
  }

  void _removeUnit(int idx) {
    setState(() => _units.removeAt(idx));
  }

  void _updateUnit(int idx, _UnitEntry updated) {
    setState(() => _units[idx] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) => _save(),
          ),
        },
        child: Dialog(
          insetPadding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 740,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_shopping_cart_rounded,
                        color: AppTheme.accent, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      widget.record == null
                          ? 'Restock Barang'
                          : 'Edit Data Restock',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    ),
                  ]),
                ),

                // ── Body ────────────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _productSummary(),
                      const SizedBox(height: 24),

                      // Qty & Unit Selection
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: ScrollableQtyField(
                            controller: _qty,
                            onChanged: (_) => _calculateCost(),
                            child: TextFormField(
                              controller: _qty,
                              decoration: const InputDecoration(labelText: 'Jumlah Tambahan *'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _calculateCost(),
                              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Wajib diisi' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: DropdownButtonFormField<ProductUnit>(
                              initialValue: _selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Satuan Pembelian', isDense: true),
                              dropdownColor: AppTheme.surfaceAlt,
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

                      // ── Section: Biaya & Supplier ──────────────────
                      _sectionLabel(context, 'Biaya & Supplier'),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Metode Perhitungan Modal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Pilih Otomatis jika ingin menghitung modal dari total beli + ongkir', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('Otomatis', style: TextStyle(fontSize: 11, fontWeight: !_isManualCost ? FontWeight.bold : FontWeight.normal, color: !_isManualCost ? AppTheme.accent : AppTheme.textMuted)),
                                      Switch(
                                        value: _isManualCost,
                                        onChanged: (v) => setState(() => _isManualCost = v),
                                        activeThumbColor: AppTheme.accent,
                                      ),
                                      Text('Manual', style: TextStyle(fontSize: 11, fontWeight: _isManualCost ? FontWeight.bold : FontWeight.normal, color: _isManualCost ? AppTheme.accent : AppTheme.textMuted)),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Harga Total Supplier (Rp)',
                                        prefixText: 'Rp ',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
                                      onChanged: (_) => _calculateCost(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _supplierShippingCost,
                                      decoration: const InputDecoration(
                                        labelText: 'Total Ongkos Kirim (Rp)',
                                        prefixText: 'Rp ',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
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
                                      fillColor: !_isManualCost ? AppTheme.bg.withValues(alpha: 0.5) : null,
                                      filled: !_isManualCost,
                                      helperText: !_isManualCost ? 'Dihitung otomatis: (Beli+Ongkir)/Qty' : 'Input harga modal akhir per unit',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [CurrencyInputFormatter()],
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) => Formatters.parseDecimal(v ?? '') == 0 && (v ?? '').isNotEmpty && (v ?? '') != '0' ? 'Format salah' : (Formatters.parseDecimal(v ?? '') == 0 && (v ?? '').isEmpty ? 'Wajib diisi' : null),
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
                                        icon: const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.warning, size: 20),
                                        tooltip: 'Saran Harga (+10%)',
                                        onPressed: _suggestPrice,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [CurrencyInputFormatter()],
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      final sell = Formatters.parseDecimal(v ?? '');
                                      final cost = Formatters.parseDecimal(_totalCostPerUnit.text);
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
                                color: _netProfit >= 0 ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (_netProfit >= 0 ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                                    color: _netProfit >= 0 ? AppTheme.success : AppTheme.danger, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Estimasi Profit Bersih:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(Formatters.currency(_netProfit), 
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _netProfit >= 0 ? AppTheme.success : AppTheme.danger)),
                                  Text(' / unit', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Section: Pengiriman & Supplier (Detail) ─────
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
                                      icon: const Icon(Icons.add_business_rounded, size: 16, color: AppTheme.accent),
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
                                      initialValue: _selectedSupplierId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Pilih Supplier', isDense: true),
                                      dropdownColor: AppTheme.surfaceAlt,
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('Input Manual / Umum', style: TextStyle(fontSize: 12))),
                                        ...list.map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12))),
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
                                                onPressed: () => _showQuickAddSupplier(context, supplier: s),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.danger),
                                                onPressed: () async {
                                                  final ok = await showConfirmDialog(context, 
                                                    title: 'Hapus Supplier', 
                                                    content: 'Yakin hapus supplier "${s.name}"?');
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
                                  loading: () => const AppLoading(),
                                  error: (_, __) => const Text('Gagal memuat'),
                                ),
                                if (_selectedSupplierId == null) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _supplierName,
                                    decoration: const InputDecoration(labelText: 'Nama Supplier (Manual)', hintText: 'Opsional', isDense: true),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _paymentStatusDropdown(
                                  label: 'Status Bayar Barang',
                                  value: _supplierPaymentStatus,
                                  onChanged: (v) => setState(() => _supplierPaymentStatus = v!),
                                ),
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
                                    const Text('Informasi Ekspedisi / Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () => _showQuickAddShipping(context),
                                      icon: const Icon(Icons.local_shipping_rounded, size: 16, color: AppTheme.accent),
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
                                      initialValue: _selectedShippingId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Pilih Ekspedisi', isDense: true),
                                      dropdownColor: AppTheme.surfaceAlt,
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('Input Manual / Umum', style: TextStyle(fontSize: 12))),
                                        ...list.map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12))),
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
                                                onPressed: () => _showQuickAddShipping(context, shipping: s),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.danger),
                                                onPressed: () async {
                                                  final ok = await showConfirmDialog(context, 
                                                    title: 'Hapus Ekspedisi', 
                                                    content: 'Yakin hapus ekspedisi "${s.name}"?');
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
                                  loading: () => const AppLoading(),
                                  error: (_, __) => const Text('Gagal memuat'),
                                ),
                                if (_selectedShippingId == null) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _shippingServiceName,
                                    decoration: const InputDecoration(labelText: 'Nama Ekspedisi (Manual)', hintText: 'Opsional', isDense: true),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _paymentStatusDropdown(
                                  label: 'Status Bayar Ongkir',
                                  value: _shippingPaymentStatus,
                                  onChanged: (v) => setState(() => _shippingPaymentStatus = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Batch Ini',
                          hintText: 'Tambahkan keterangan atau nomor nota...',
                        ),
                      ),
                      const SizedBox(height: 28),

                      Row(children: [
                        _sectionLabel(context, 'Satuan Jual & Harga (Opsional)'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addUnit,
                          icon:  const Icon(Icons.add_circle_outline_rounded, size: 16),
                          label: const Text('Tambah Satuan'),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      if (_units.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Gunakan daftar di atas untuk mengupdate harga jual dasar. Klik "Tambah Satuan" jika ada pembagian satuan jual baru untuk produk ini.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border:       Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: const BoxDecoration(
                                color:        AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                              ),
                              child: Row(children: [
                                Expanded(flex: 2, child: _th('Nama Satuan')),
                                Expanded(flex: 3, child: _th('Konversi (1 satuan = ? satuan dasar)')),
                                Expanded(flex: 2, child: _th('Harga Jual (Rp)')),
                                const SizedBox(width: 36),
                              ]),
                            ),
                            ..._units.asMap().entries.map((e) => _UnitRowWidget(
                                  key:      ValueKey(e.value.id),
                                  entry:    e.value,
                                  baseUnit: widget.product.baseUnit,
                                  isLast:   e.key == _units.length - 1,
                                  canDelete: true,
                                  onChanged: (updated) => _updateUnit(e.key, updated),
                                  onDelete:  () => _removeUnit(e.key),
                                )),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_task_rounded, size: 18),
                  label: Text(_saving ? 'Menyimpan...' : 'Tambah Stok'),
                ),
              ]),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _productSummary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.surfaceAlt.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      const Icon(Icons.inventory_2_outlined, color: AppTheme.accent, size: 20),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text('Stok Saat Ini: ${Formatters.decimal(widget.product.stock)} ${widget.product.baseUnit}', 
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ])),
    ]),
  );

  Widget _paymentStatusDropdown({
    required String label,
    required PaymentStatus value,
    required ValueChanged<PaymentStatus?> onChanged,
  }) {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<PaymentStatus>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        dropdownColor: AppTheme.surfaceAlt,
        items: [PaymentStatus.paid, PaymentStatus.unpaid, PaymentStatus.partial].map((s) => DropdownMenuItem(
          value: s,
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(s)),
              ),
              const SizedBox(width: 8),
              Text(s.label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _showQuickAddSupplier(BuildContext context, {Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name);
    final phoneCtrl = TextEditingController(text: supplier?.phone);
    final addrCtrl = TextEditingController(text: supplier?.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'Tambah Supplier Baru' : 'Edit Supplier'),
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
                final s = (supplier ?? Supplier(id: _uuid.v4(), name: '', createdAt: DateTime.now())).copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveSupplier(s);
                setState(() => _selectedSupplierId = s.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddShipping(BuildContext context, {ShippingService? shipping}) {
    final nameCtrl = TextEditingController(text: shipping?.name);
    final phoneCtrl = TextEditingController(text: shipping?.phone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shipping == null ? 'Tambah Ekspedisi Baru' : 'Edit Ekspedisi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Ekspedisi/Supir *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = (shipping ?? ShippingService(id: _uuid.v4(), name: '', createdAt: DateTime.now())).copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveShippingService(s);
                setState(() => _selectedShippingId = s.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid: return AppTheme.success;
      case PaymentStatus.unpaid: return AppTheme.warning;
      case PaymentStatus.partial: return AppTheme.info;
      case PaymentStatus.notApplicable: return AppTheme.textMuted;
    }
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Row(children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent)),
    ]);
  }

  Widget _th(String label) => Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3,
        ),
      );
}

// ── Unit entry data ────────────────────────────────────────────────────────

class _UnitEntry {
  final String id;
  final String productId;
  String unitName;
  String conversionRate;
  String sellPrice;

  _UnitEntry({
    required this.id,
    required this.productId,
    this.unitName      = '',
    this.conversionRate = '1',
    this.sellPrice      = '0',
  });

  factory _UnitEntry.fromUnit(ProductUnit u) => _UnitEntry(
        id:             u.id,
        productId:      u.productId,
        unitName:       u.unitName,
        conversionRate: u.conversionRate.toStringAsFixed(u.conversionRate % 1 == 0 ? 0 : 2),
        sellPrice:      u.sellPrice.toStringAsFixed(0),
      );

  ProductUnit toUnit(String pid) => ProductUnit(
        id:             id,
        productId:      pid,
        unitName:       unitName.trim(),
        conversionRate: Formatters.parseDecimal(conversionRate),
        sellPrice:      Formatters.parseDecimal(sellPrice),
      );
}

// ── Unit Row Widget ────────────────────────────────────────────────────────

class _UnitRowWidget extends StatefulWidget {
  final _UnitEntry   entry;
  final String       baseUnit;
  final bool         isLast;
  final bool         canDelete;
  final ValueChanged<_UnitEntry> onChanged;
  final VoidCallback onDelete;

  const _UnitRowWidget({
    super.key,
    required this.entry,
    required this.baseUnit,
    required this.isLast,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_UnitRowWidget> createState() => _UnitRowWidgetState();
}

class _UnitRowWidgetState extends State<_UnitRowWidget> {
  late TextEditingController _unitCtrl, _convCtrl, _priceCtrl;

  @override
  void initState() {
    super.initState();
    _unitCtrl  = TextEditingController(text: widget.entry.unitName);
    _convCtrl  = TextEditingController(text: widget.entry.conversionRate);
    _priceCtrl = TextEditingController(text: widget.entry.sellPrice);
  }

  @override
  void dispose() {
    _unitCtrl.dispose();
    _convCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_UnitEntry(
      id:             widget.entry.id,
      productId:      widget.entry.productId,
      unitName:       _unitCtrl.text,
      conversionRate: _convCtrl.text,
      sellPrice:      _priceCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top:    const BorderSide(color: AppTheme.border),
          bottom: widget.isLast ? BorderSide.none : BorderSide.none,
        ),
        borderRadius: widget.isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(9))
            : BorderRadius.zero,
      ),
      child: Row(children: [
        // Unit name
        Expanded(
          flex: 2,
          child: TextFormField(
            controller:  _unitCtrl,
            onChanged:   (_) => _notify(),
            decoration:  InputDecoration(
              hintText:   'e.g. roll, sack, box',
              isDense:    true,
              suffixText: _unitCtrl.text.isNotEmpty ? '' : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Conversion
        Expanded(
          flex: 3,
          child: Row(children: [
            const Text('1 ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Expanded(
              child: TextFormField(
                controller:  _unitCtrl,
                readOnly:    true,
                decoration:  InputDecoration(
                  isDense:     true,
                  hintText:    _unitCtrl.text.isEmpty ? 'satuan' : null,
                  fillColor:   AppTheme.bg,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child:   Text('=', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: TextFormField(
                controller:   _convCtrl,
                onChanged:    (_) => _notify(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:   InputDecoration(
                  isDense:      true,
                  suffixText:   widget.baseUnit,
                  suffixStyle:  const TextStyle(color: AppTheme.accent, fontSize: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // Sell price
        Expanded(
          flex: 2,
          child: TextFormField(
            controller:   _priceCtrl,
            onChanged:    (_) => _notify(),
            keyboardType: TextInputType.number,
            decoration:   const InputDecoration(
              isDense:    true,
              prefixText: 'Rp ',
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Delete button
        SizedBox(
          width: 28,
          child: widget.canDelete
              ? IconButton(
                  padding:   EdgeInsets.zero,
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: AppTheme.danger, size: 20),
                )
              : const SizedBox(),
        ),
      ]),
    );
  }
}
