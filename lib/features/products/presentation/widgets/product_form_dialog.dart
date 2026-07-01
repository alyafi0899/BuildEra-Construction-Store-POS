import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';
import '../../providers/entity_provider.dart';
import '../../models/supplier.dart';
import '../../models/shipping_service.dart';
import '../../../auth/providers/auth_provider.dart';

import '../../../../core/utils/barcode_helper.dart';
import '../../providers/barcode_history_provider.dart';

import '../../models/product_financials.dart';

final _uuid = Uuid();

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormDialog({super.key, this.product});

  static Future<void> show(BuildContext context, {Product? product}) {
    return showDialog(
      context:            context,
      barrierDismissible: false,
      builder:            (_) => ProductFormDialog(product: product),
    );
  }

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _barcode, _description, _costPrice, _basePrice, _stock, _categoryCtrl, _baseUnitCtrl;
  late final TextEditingController _supplierPrice, _supplierShippingCost, _supplierName, _shippingServiceName;
  String? _defaultUnitName;
  late List<_UnitEntry> _units;
  Uint8List? _imageBytes;
  String? _existingImagePath;
  bool _saving = false;
  bool _generatingBarcode = false;

  // Financial state
  bool _isManualCost = false;
  PaymentStatus _supplierPaymentStatus = PaymentStatus.notApplicable;
  PaymentStatus _shippingPaymentStatus = PaymentStatus.notApplicable;
  
  String? _selectedSupplierId;
  String? _selectedShippingId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final f = p?.financials ?? const ProductFinancials();
    
    _name      = TextEditingController(text: p?.name ?? '');
    _barcode   = TextEditingController(text: p?.barcode ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _costPrice = TextEditingController(text: p != null ? p.costPrice.toStringAsFixed(0) : '');
    _basePrice = TextEditingController(text: p != null ? p.basePrice.toStringAsFixed(0) : '');
    _stock     = TextEditingController(text: p != null ? p.stock.toStringAsFixed(0) : '0');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _baseUnitCtrl = TextEditingController(text: p?.baseUnit ?? 'pcs');
    
    _supplierPrice = TextEditingController(text: f.supplierPrice > 0 ? f.supplierPrice.toStringAsFixed(0) : '');
    _supplierShippingCost = TextEditingController(text: f.supplierShippingCost > 0 ? f.supplierShippingCost.toStringAsFixed(0) : '');
    _supplierName = TextEditingController(text: f.supplierName ?? '');
    _shippingServiceName = TextEditingController(text: f.shippingServiceName ?? '');
    
    _isManualCost = f.isManualCost;
    _supplierPaymentStatus = f.supplierPaymentStatus;
    _shippingPaymentStatus = f.shippingPaymentStatus;

    _defaultUnitName = p?.defaultUnitName;
    _existingImagePath = p?.imagePath;
    _units     = p?.units.map((u) => _UnitEntry.fromUnit(u)).toList() ?? [];
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _description.dispose();
    _costPrice.dispose();
    _basePrice.dispose();
    _stock.dispose();
    _categoryCtrl.dispose();
    _baseUnitCtrl.dispose();
    _supplierPrice.dispose();
    _supplierShippingCost.dispose();
    _supplierName.dispose();
    _shippingServiceName.dispose();
    super.dispose();
  }

  void _updateCalculatedCost() {
    if (_isManualCost) return;
    
    final supplierPrice = double.tryParse(_supplierPrice.text) ?? 0;
    final shippingCost = double.tryParse(_supplierShippingCost.text) ?? 0;
    final qty = double.tryParse(_stock.text) ?? 0;
    
    if (qty > 0) {
      final totalCost = (supplierPrice + shippingCost) / qty;
      setState(() {
        _costPrice.text = totalCost.toStringAsFixed(0);
      });
    }
  }

  void _suggestPrice() {
    final cost = double.tryParse(_costPrice.text) ?? 0;
    if (cost > 0) {
      final suggested = cost * 1.1; // +10%
      setState(() {
        _basePrice.text = suggested.toStringAsFixed(0);
      });
    }
  }

  double get _netProfit {
    final cost = double.tryParse(_costPrice.text) ?? 0;
    final sell = double.tryParse(_basePrice.text) ?? 0;
    return sell - cost;
  }

  Future<void> _pickImage() async {
    final bytes = await ImageHelper.pickAndCropImage(context);
    if (bytes != null) {
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _generateBarcode() async {
    setState(() => _generatingBarcode = true);
    try {
      final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
      String newBarcode = '';
      bool isUnique = false;
      int attempts = 0;

      while (!isUnique && attempts < 10) {
        final rawData = BarcodeHelper.generateRandomEAN13Data();
        newBarcode = BarcodeHelper.getEAN13WithCheckDigit(rawData);
        
        final used = await historyRepo.isBarcodeUsed(newBarcode);
        if (!used) {
          isUnique = true;
        }
        attempts++;
      }

      if (isUnique) {
        setState(() {
          _barcode.text = newBarcode;
        });
      } else {
        if (mounted) showError(context, 'Gagal membuat barcode unik. Silakan coba lagi.');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error saat membuat barcode: $e');
    } finally {
      if (mounted) setState(() => _generatingBarcode = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final validUnits = <ProductUnit>[];
    final productId = widget.product?.id ?? _uuid.v4();
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final suppliers = ref.read(suppliersProvider).asData?.value ?? [];
    final shippings = ref.read(shippingServicesProvider).asData?.value ?? [];
    
    final supplierName = _selectedSupplierId != null 
        ? suppliers.firstWhereOrNull((s) => s.id == _selectedSupplierId)?.name 
        : _supplierName.text.trim().isEmpty ? null : _supplierName.text.trim();
        
    final shippingName = _selectedShippingId != null 
        ? shippings.firstWhereOrNull((s) => s.id == _selectedShippingId)?.name 
        : _shippingServiceName.text.trim().isEmpty ? null : _shippingServiceName.text.trim();

    for (final u in _units) {
      if (u.unitName.trim().isNotEmpty) {
        validUnits.add(u.toUnit(productId));
      }
    }

    setState(() => _saving = true);
    try {
      String? imagePath = _existingImagePath;
      if (_imageBytes != null) {
        final processed = await ImageHelper.processImage(_imageBytes!);
        imagePath = await ImageHelper.saveLocally(user.uid, productId, processed);
      }

      final product = Product(
        id:        productId,
        name:      _name.text.trim(),
        category:  _categoryCtrl.text.trim().isEmpty ? 'Umum' : _categoryCtrl.text.trim(),
        barcode:   _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        costPrice: double.tryParse(_costPrice.text) ?? 0,
        basePrice: double.tryParse(_basePrice.text) ?? 0,
        baseUnit:  _baseUnitCtrl.text.trim().isEmpty ? 'pcs' : _baseUnitCtrl.text.trim(),
        defaultUnitName: _defaultUnitName,
        stock:     double.tryParse(_stock.text) ?? 0,
        imagePath: imagePath,
        financials: ProductFinancials(
          supplierPrice: double.tryParse(_supplierPrice.text) ?? 0,
          supplierShippingCost: double.tryParse(_supplierShippingCost.text) ?? 0,
          isManualCost: _isManualCost,
          supplierName: supplierName,
          supplierPaymentStatus: _supplierPaymentStatus,
          shippingServiceName: shippingName,
          shippingPaymentStatus: _shippingPaymentStatus,
        ),
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(productsActionProvider).saveProduct(product, validUnits);
      if (mounted) {
        Navigator.of(context).pop();
        showSuccess(
          context,
          widget.product == null ? 'Produk berhasil ditambahkan' : 'Produk berhasil diperbarui',
        );
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addUnit() {
    setState(() => _units.add(_UnitEntry(id: _uuid.v4(), productId: widget.product?.id ?? '')));
  }

  void _removeUnit(int idx) {
    setState(() => _units.removeAt(idx));
  }

  void _updateUnit(int idx, _UnitEntry updated) {
    setState(() => _units[idx] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 740,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_rounded, color: AppTheme.accent, size: 22),
                const SizedBox(width: 12),
                Text(
                  widget.product == null ? 'Tambah Produk Baru' : 'Edit Produk',
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
                      // Image & Basic Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImagePicker(),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                // Row 1: name + barcode
                                Row(children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _name,
                                      decoration: const InputDecoration(labelText: 'Nama Produk *'),
                                      validator:  (v) => v!.trim().isEmpty ? 'Nama wajib diisi' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _barcode,
                                      decoration: InputDecoration(
                                        labelText:  'Barcode',
                                        hintText:   'Scan atau ketik barcode',
                                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                        suffixIcon: _generatingBarcode 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                          : IconButton(
                                              icon: const Icon(Icons.auto_fix_high_rounded, size: 18, color: AppTheme.accent),
                                              tooltip: 'Generate Barcode',
                                              onPressed: _generateBarcode,
                                            ),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _description,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Deskripsi Produk',
                                    hintText: 'Tambahkan keterangan detail mengenai produk ini...',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Kategori Produk *', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        const SizedBox(height: 8),
                                        Autocomplete<String>(
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            final list = ref.read(productsProvider).asData?.value.map((p) => p.category).toSet().toList() ?? [];
                                            final combined = {...AppConstants.categories, ...list}.toList();
                                            if (textEditingValue.text.isEmpty) {
                                              return combined;
                                            }
                                            return combined.where((String option) {
                                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                            });
                                          },
                                          onSelected: (String selection) {
                                            _categoryCtrl.text = selection;
                                          },
                                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                            if (controller.text.isEmpty && _categoryCtrl.text.isNotEmpty) {
                                              controller.text = _categoryCtrl.text;
                                            }
                                            return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (v) => _categoryCtrl.text = v,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori Produk *',
                                      hintText: 'Pilih atau ketik baru...',
                                      suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
                                    ),
                                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final list = ref.read(productsProvider).asData?.value.map((p) => p.baseUnit).toSet().toList() ?? [];
                              final combined = {...AppConstants.baseUnits, ...list}.toList();
                              if (textEditingValue.text.isEmpty) {
                                return combined;
                              }
                              return combined.where((String option) {
                                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (String selection) {
                              setState(() {
                                _baseUnitCtrl.text = selection;
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              if (controller.text.isEmpty && _baseUnitCtrl.text.isNotEmpty) {
                                controller.text = _baseUnitCtrl.text;
                              }
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: (v) => setState(() => _baseUnitCtrl.text = v),
                                decoration: const InputDecoration(
                                  labelText: 'Satuan Dasar *',
                                  hintText: 'e.g. pcs, kg, m',
                                  suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
                                ),
                                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller:   _stock,
                            decoration:   const InputDecoration(labelText: 'Jumlah Barang *'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _updateCalculatedCost(),
                            validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ),
                      ]),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                                      onChanged: (_) => _updateCalculatedCost(),
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
                                      onChanged: (_) => _updateCalculatedCost(),
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
                                    controller: _costPrice,
                                    readOnly: !_isManualCost,
                                    decoration: InputDecoration(
                                      labelText: 'Total Modal per Unit (Rp) *',
                                      prefixText: 'Rp ',
                                      fillColor: !_isManualCost ? AppTheme.bg.withValues(alpha: 0.5) : null,
                                      filled: !_isManualCost,
                                      helperText: !_isManualCost ? 'Dihitung otomatis: (Beli+Ongkir)/Qty' : 'Input harga modal akhir per unit',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}), // Trigger profit update
                                    validator: (v) => double.tryParse(v ?? '') == null ? 'Wajib diisi' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
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
                                        onChanged: (_) => setState(() {}),
                                        validator: (v) {
                                          final sell = double.tryParse(v ?? '') ?? 0;
                                          final cost = double.tryParse(_costPrice.text) ?? 0;
                                          if (sell <= 0) return 'Wajib diisi';
                                          if (sell < cost) return 'Harga jual di bawah modal';
                                          return null;
                                        },
                                      ),
                                    ],
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
                                      initialValue: list.any((s) => s.id == _selectedSupplierId) ? _selectedSupplierId : (widget.product?.financials.supplierName != null ? list.firstWhereOrNull((s) => s.name == widget.product?.financials.supplierName)?.id : null),
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
                                      initialValue: list.any((s) => s.id == _selectedShippingId) ? _selectedShippingId : (widget.product?.financials.shippingServiceName != null ? list.firstWhereOrNull((s) => s.name == widget.product?.financials.shippingServiceName)?.id : null),
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
                            'Hanya gunakan Satuan Dasar untuk penjualan ini. Klik "Tambah Satuan" jika ingin menjual dalam satuan lain (seperti Box, Dus, dll).',
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
                                Expanded(flex: 2, child: _th('Satuan Jual')),
                                const SizedBox(width: 12),
                                Expanded(flex: 3, child: _th('Konversi (ke Dasar)')),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: _th('Harga Jual')),
                                const SizedBox(width: 44),
                              ]),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics:    const NeverScrollableScrollPhysics(),
                              itemCount:  _units.length,
                              itemBuilder: (context, i) => _UnitRowWidget(
                                key:       ValueKey(_units[i].id),
                                entry:     _units[i],
                                baseUnit:  _baseUnitCtrl.text,
                                isLast:    i == _units.length - 1,
                                canDelete: _units.length > 0,
                                onChanged: (u) => _updateUnit(i, u),
                                onDelete:  () => _removeUnit(i),
                              ),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 32),
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
                  child:     const Text('Batal'),
                ),
                const Spacer(),
                SizedBox(
                  width:  200,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:  _saving ? const AppLoading() : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Produk'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width:  160,
        height: 160,
        decoration: BoxDecoration(
          color:        AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppTheme.border),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              )
            : widget.product?.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(widget.product!.imagePath!), fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: AppTheme.textMuted, size: 32),
                      SizedBox(height: 8),
                      Text('Foto Produk', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
      ),
    );
  }

  Widget _paymentStatusDropdown({
    required String label,
    required PaymentStatus value,
    required ValueChanged<PaymentStatus?> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              SizedBox(
                height: 42,
                child: DropdownButtonFormField<PaymentStatus>(
                  value: value,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  dropdownColor: AppTheme.surfaceAlt,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  items: PaymentStatus.values.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name.toUpperCase(), style: TextStyle(color: _statusColor(s), fontWeight: FontWeight.bold, fontSize: 11)),
                  )).toList(),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
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
        conversionRate: double.tryParse(conversionRate) ?? 1,
        sellPrice:      double.tryParse(sellPrice) ?? 0,
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
              isDense:     true,
              prefixText:  'Rp ',
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (widget.canDelete)
          IconButton(
            onPressed: widget.onDelete,
            icon:      const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
            padding:   EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
    );
  }
}
