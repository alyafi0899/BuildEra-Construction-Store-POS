// lib/features/products/presentation/widgets/product_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final ProductEntity? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _basePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descCtrl;

  String _selectedCategory = AppConstants.categories.first;
  String _selectedBaseUnit = AppConstants.baseUnits.first;
  List<_UnitRow> _unitRows = [];
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _basePriceCtrl = TextEditingController(text: p?.basePrice.toInt().toString() ?? '');
    _stockCtrl = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _selectedCategory = p?.category ?? AppConstants.categories.first;
    _selectedBaseUnit = p?.baseUnit ?? AppConstants.baseUnits.first;

    if (p != null && p.units.isNotEmpty) {
      _unitRows = p.units
          .map((u) => _UnitRow(
                unitName: u.unitName,
                conversionRatio: u.conversionRatio.toString(),
                sellingPrice: u.sellingPrice.toInt().toString(),
                isBaseUnit: u.isBaseUnit,
              ))
          .toList();
    } else {
      _unitRows = [
        _UnitRow(
          unitName: _selectedBaseUnit,
          conversionRatio: '1',
          sellingPrice: '',
          isBaseUnit: true,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _basePriceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addUnitRow() {
    setState(() {
      _unitRows.add(_UnitRow(
        unitName: '',
        conversionRatio: '',
        sellingPrice: '',
        isBaseUnit: false,
      ));
    });
  }

  void _removeUnitRow(int index) {
    if (_unitRows[index].isBaseUnit) return;
    setState(() => _unitRows.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate units
    for (final row in _unitRows) {
      if (!row.isBaseUnit) {
        if (row.unitName.isEmpty) {
          showErrorSnackbar(context, 'Nama satuan tidak boleh kosong');
          return;
        }
        if (row.conversionRatio.isEmpty || double.tryParse(row.conversionRatio) == null) {
          showErrorSnackbar(context, 'Rasio konversi tidak valid untuk satuan ${row.unitName}');
          return;
        }
      }
      if (row.sellingPrice.isEmpty || double.tryParse(row.sellingPrice) == null) {
        showErrorSnackbar(context, 'Harga jual tidak valid');
        return;
      }
    }

    setState(() => _saving = true);

    final product = ProductEntity(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      category: _selectedCategory,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      basePrice: double.parse(_basePriceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')),
      baseUnit: _selectedBaseUnit,
      stockQuantity: double.tryParse(_stockCtrl.text) ?? 0,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    final units = _unitRows.map((row) => ProductUnitEntity(
      productId: widget.product?.id ?? 0,
      unitName: row.isBaseUnit ? _selectedBaseUnit : row.unitName,
      conversionRatio: row.isBaseUnit ? 1 : double.parse(row.conversionRatio),
      sellingPrice: double.parse(row.sellingPrice),
      isBaseUnit: row.isBaseUnit,
    )).toList();

    bool success;
    if (_isEdit) {
      success = await ref.read(productNotifierProvider.notifier).updateProduct(
        product: product,
        units: units,
      );
    } else {
      success = await ref.read(productNotifierProvider.notifier).addProduct(
        product: product,
        units: units,
      );
    }

    setState(() => _saving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        showSuccessSnackbar(context, _isEdit ? 'Produk berhasil diperbarui' : 'Produk berhasil ditambahkan');
      } else {
        showErrorSnackbar(context, 'Gagal menyimpan produk');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Edit Produk' : 'Tambah Produk Baru',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      _sectionLabel('Informasi Produk'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Nama Produk *'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Nama produk wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _barcodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Barcode',
                                prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(labelText: 'Kategori *'),
                              dropdownColor: AppColors.surfaceVariant,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              items: AppConstants.categories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _descCtrl,
                              decoration: const InputDecoration(labelText: 'Deskripsi'),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 16),

                      // Pricing & Stock Section
                      _sectionLabel('Harga & Stok'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _basePriceCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Harga Dasar *',
                                prefixText: 'Rp ',
                              ),
                              validator: (v) {
                                if (v?.isEmpty == true) return 'Harga wajib diisi';
                                if (double.tryParse(v!) == null) return 'Harga tidak valid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedBaseUnit,
                              decoration: const InputDecoration(labelText: 'Satuan Dasar *'),
                              dropdownColor: AppColors.surfaceVariant,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              items: AppConstants.baseUnits
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedBaseUnit = v!;
                                  // Update base unit row
                                  final idx = _unitRows.indexWhere((r) => r.isBaseUnit);
                                  if (idx >= 0) _unitRows[idx].unitName = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stockCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              decoration: InputDecoration(
                                labelText: 'Stok Awal',
                                suffixText: _selectedBaseUnit,
                              ),
                              validator: (v) {
                                if (v?.isEmpty == true) return null;
                                if (double.tryParse(v!) == null) return 'Stok tidak valid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 16),

                      // Units Section
                      Row(
                        children: [
                          _sectionLabel('Satuan Jual'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addUnitRow,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah Satuan'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Unit rows
                      ..._unitRows.asMap().entries.map((e) {
                        final index = e.key;
                        final row = e.value;
                        return _UnitRowWidget(
                          key: ValueKey(index),
                          row: row,
                          baseUnit: _selectedBaseUnit,
                          onRemove: row.isBaseUnit ? null : () => _removeUnitRow(index),
                          onChanged: () => setState(() {}),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Produk'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─── UNIT ROW MODEL ──────────────────────────────────────────────────────────

class _UnitRow {
  String unitName;
  String conversionRatio;
  String sellingPrice;
  final bool isBaseUnit;

  _UnitRow({
    required this.unitName,
    required this.conversionRatio,
    required this.sellingPrice,
    required this.isBaseUnit,
  });
}

class _UnitRowWidget extends StatefulWidget {
  final _UnitRow row;
  final String baseUnit;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _UnitRowWidget({
    super.key,
    required this.row,
    required this.baseUnit,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_UnitRowWidget> createState() => _UnitRowWidgetState();
}

class _UnitRowWidgetState extends State<_UnitRowWidget> {
  late final TextEditingController _unitNameCtrl;
  late final TextEditingController _ratioCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _unitNameCtrl = TextEditingController(text: widget.row.unitName);
    _ratioCtrl = TextEditingController(text: widget.row.conversionRatio);
    _priceCtrl = TextEditingController(text: widget.row.sellingPrice);
  }

  @override
  void dispose() {
    _unitNameCtrl.dispose();
    _ratioCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.row.isBaseUnit
            ? AppColors.primaryContainer.withValues(alpha: 0.4)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.row.isBaseUnit ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          if (widget.row.isBaseUnit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Dasar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),

          // Unit name
          Expanded(
            flex: 2,
            child: widget.row.isBaseUnit
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      widget.baseUnit,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    ),
                  )
                : TextField(
                    controller: _unitNameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Nama satuan',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      widget.row.unitName = v;
                      widget.onChanged();
                    },
                  ),
          ),
          const SizedBox(width: 8),

          // Conversion ratio
          Expanded(
            flex: 2,
            child: widget.row.isBaseUnit
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '1 ${widget.baseUnit} = 1 ${widget.baseUnit}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                : TextField(
                    controller: _ratioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rasio',
                      suffixText: widget.baseUnit,
                      suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      widget.row.conversionRatio = v;
                      widget.onChanged();
                    },
                  ),
          ),
          const SizedBox(width: 8),

          // Selling price
          Expanded(
            flex: 2,
            child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Harga jual',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (v) {
                widget.row.sellingPrice = v;
                widget.onChanged();
              },
            ),
          ),

          const SizedBox(width: 8),
          if (widget.onRemove != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
              tooltip: 'Hapus satuan',
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
