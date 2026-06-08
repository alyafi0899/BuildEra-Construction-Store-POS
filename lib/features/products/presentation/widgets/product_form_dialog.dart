import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';

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
  late final TextEditingController _name, _barcode, _costPrice, _basePrice, _stock;
  late String _category, _baseUnit;
  String? _defaultUnitName;
  late List<_UnitEntry> _units;
  Uint8List? _imageBytes;
  String? _existingImagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name      = TextEditingController(text: p?.name ?? '');
    _barcode   = TextEditingController(text: p?.barcode ?? '');
    _costPrice = TextEditingController(text: p != null ? p.costPrice.toStringAsFixed(0) : '');
    _basePrice = TextEditingController(text: p != null ? p.basePrice.toStringAsFixed(0) : '');
    _stock     = TextEditingController(text: p != null ? p.stock.toStringAsFixed(0) : '0');
    _category  = p?.category.isNotEmpty == true ? p!.category : AppConstants.categories.first;
    _baseUnit  = p?.baseUnit ?? 'pcs';
    _defaultUnitName = p?.defaultUnitName;
    _existingImagePath = p?.imagePath;
    _units     = p?.units.map((u) => _UnitEntry.fromUnit(u)).toList() ?? [];
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _costPrice.dispose();
    _basePrice.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      setState(() => _imageBytes = result.files.first.bytes);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Process units: ignore rows with empty names
    final validUnits = <ProductUnit>[];
    final productId = widget.product?.id ?? _uuid.v4();

    for (final u in _units) {
      if (u.unitName.trim().isNotEmpty) {
        validUnits.add(u.toUnit(productId));
      }
    }

    setState(() => _saving = true);
    try {
      String? imagePath = _existingImagePath;
      if (_imageBytes != null) {
        // 1. Save locally for instant access (if not on web)
        final localPath = await ImageHelper.saveLocally(productId, _imageBytes!);
        if (localPath != null) imagePath = localPath;

        // 2. Upload to Firebase Storage with compression
        imagePath = await ref.read(productsActionProvider).uploadImage(productId, _imageBytes!);
      }

      final product = Product(
        id:        productId,
        name:      _name.text.trim(),
        category:  _category,
        barcode:   _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        costPrice: double.tryParse(_costPrice.text) ?? 0,
        basePrice: double.tryParse(_basePrice.text) ?? 0,
        baseUnit:  _baseUnit,
        defaultUnitName: _defaultUnitName,
        stock:     double.tryParse(_stock.text) ?? 0,
        imagePath: imagePath,
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
                      // Image Picker
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border),
                                  image: _imageBytes != null 
                                    ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                                    : (_existingImagePath != null 
                                        ? DecorationImage(image: NetworkImage(_existingImagePath!), fit: BoxFit.cover)
                                        : null),
                                ),
                                child: (_imageBytes == null && _existingImagePath == null)
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_rounded, color: AppTheme.textSecondary, size: 32),
                                          SizedBox(height: 8),
                                          Text('Tambah Foto', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            if (_imageBytes != null || _existingImagePath != null)
                              TextButton(
                                onPressed: () => setState(() { _imageBytes = null; _existingImagePath = null; }),
                                child: const Text('Hapus Foto', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section label
                      _sectionLabel(context, 'Informasi Produk'),
                      const SizedBox(height: 16),

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
                            decoration: const InputDecoration(
                              labelText:  'Barcode',
                              hintText:   'Scan atau ketik barcode',
                              prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Row 2: category + base unit + stock
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:         _category,
                            decoration:    const InputDecoration(labelText: 'Kategori *'),
                            dropdownColor: AppTheme.surfaceAlt,
                            isExpanded:    true,
                            items: AppConstants.categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:         _baseUnit,
                            decoration:    const InputDecoration(labelText: 'Satuan Dasar *'),
                            dropdownColor: AppTheme.surfaceAlt,
                            items: AppConstants.baseUnits
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) => setState(() => _baseUnit = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller:   _stock,
                            decoration:   const InputDecoration(labelText: 'Stok Awal'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Row 3: cost price + base price
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller:   _costPrice,
                            decoration:   const InputDecoration(
                              labelText:  'Harga Modal (Rp) *',
                              prefixText: 'Rp ',
                              helperText: 'Harga beli dari supplier',
                            ),
                            keyboardType: TextInputType.number,
                            validator:    (v) =>
                                (double.tryParse(v ?? '') == null) ? 'Masukkan angka valid' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller:   _basePrice,
                            decoration:   const InputDecoration(
                              labelText:  'Harga Jual Dasar (Rp) *',
                              prefixText: 'Rp ',
                              helperText: 'Harga jual default untuk satuan dasar',
                            ),
                            keyboardType: TextInputType.number,
                            validator:    (v) =>
                                (double.tryParse(v ?? '') == null) ? 'Masukkan angka valid' : null,
                          ),
                        ),
                      ]),
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
                            // Table header
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
                                  baseUnit: _baseUnit,
                                  isLast:   e.key == _units.length - 1,
                                  canDelete: true,
                                  onChanged: (updated) => _updateUnit(e.key, updated),
                                  onDelete:  () => _removeUnit(e.key),
                                )),
                          ]),
                        ),

                      if (_units.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionLabel(context, 'Pengaturan Default'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: _defaultUnitName,
                          decoration: const InputDecoration(
                            labelText: 'Satuan Default di Kasir',
                            helperText: 'Satuan ini akan otomatis terpilih saat produk discan/diklik',
                          ),
                          dropdownColor: AppTheme.surfaceAlt,
                          items: [
                            DropdownMenuItem(value: null, child: Text('Default (Satuan Pertama)')),
                            DropdownMenuItem(value: _baseUnit, child: Text('Satuan Dasar ($_baseUnit)')),
                            ..._units.where((u) => u.unitName.isNotEmpty).map((u) => DropdownMenuItem(
                              value: u.unitName,
                              child: Text(u.unitName),
                            )),
                          ],
                          onChanged: (v) => setState(() => _defaultUnitName = v),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Contoh: 1 roll = 50 meter · 1 sack = 40 kg · 1 box = 6 pcs',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Produk'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
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
