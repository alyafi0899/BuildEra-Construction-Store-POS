import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:barcode/barcode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';

import '../../models/print_profile.dart';
import '../../providers/print_profile_provider.dart';

class BarcodeManagementPage extends ConsumerStatefulWidget {
  const BarcodeManagementPage({super.key});

  @override
  ConsumerState<BarcodeManagementPage> createState() => _BarcodeManagementPageState();
}

class _BarcodeManagementPageState extends ConsumerState<BarcodeManagementPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _sortBy = 'name'; 
  bool _sortAsc = true;
  String? _selectedProfileId;
  
  final Map<String, int> _selectedQuantities = {};
  
  // Settings with persistent controllers to avoid cursor jumping
  late final TextEditingController _ctrlPaperW, _ctrlPaperH, _ctrlLabelW, _ctrlLabelH, _ctrlBarH, _ctrlBarW, _ctrlPaperM, _ctrlLabelM, _ctrlLabelP, _ctrlCols;
  late final TextEditingController _ctrlFntName, _ctrlFntBar, _ctrlFntPrice;

  double _paperWidthMm = 210;
  double _paperHeightMm = 297;
  double _labelWidthMm = 40;
  double _labelHeightMm = 30;
  double _barcodeHeightMm = 12;
  double _barcodeWidthMm = 35;
  double _paperMarginMm = 10;
  double _labelMarginMm = 2;
  double _labelPaddingMm = 2;
  int _columnCount = 4;
  double _fontSizeName = 8;
  double _fontSizeBarcode = 7;
  double _fontSizePrice = 8;

  @override
  void initState() {
    super.initState();
    _ctrlPaperW = TextEditingController(text: _paperWidthMm.toString());
    _ctrlPaperH = TextEditingController(text: _paperHeightMm.toString());
    _ctrlLabelW = TextEditingController(text: _labelWidthMm.toString());
    _ctrlLabelH = TextEditingController(text: _labelHeightMm.toString());
    _ctrlBarH   = TextEditingController(text: _barcodeHeightMm.toString());
    _ctrlBarW   = TextEditingController(text: _barcodeWidthMm.toString());
    _ctrlPaperM = TextEditingController(text: _paperMarginMm.toString());
    _ctrlLabelM = TextEditingController(text: _labelMarginMm.toString());
    _ctrlLabelP = TextEditingController(text: _labelPaddingMm.toString());
    _ctrlCols   = TextEditingController(text: _columnCount.toString());
    _ctrlFntName = TextEditingController(text: _fontSizeName.toString());
    _ctrlFntBar = TextEditingController(text: _fontSizeBarcode.toString());
    _ctrlFntPrice = TextEditingController(text: _fontSizePrice.toString());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctrlPaperW.dispose(); _ctrlPaperH.dispose(); _ctrlLabelW.dispose(); _ctrlLabelH.dispose();
    _ctrlBarH.dispose(); _ctrlBarW.dispose(); _ctrlPaperM.dispose(); _ctrlLabelM.dispose(); _ctrlLabelP.dispose();
    _ctrlCols.dispose(); _ctrlFntName.dispose(); _ctrlFntBar.dispose(); _ctrlFntPrice.dispose();
    super.dispose();
  }

  void _toggleSelect(Product p) {
    setState(() {
      if (_selectedQuantities.containsKey(p.id)) {
        _selectedQuantities.remove(p.id);
      } else {
        _selectedQuantities[p.id] = 1;
      }
    });
  }

  void _updateQty(String id, int delta) {
    setState(() {
      final current = _selectedQuantities[id] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _selectedQuantities.remove(id);
      } else {
        _selectedQuantities[id] = next;
      }
    });
  }

  void _loadProfile(PrintProfile p) {
    setState(() {
      _selectedProfileId = p.id;
      _paperWidthMm = p.paperWidth;
      _paperHeightMm = p.paperHeight;
      _labelWidthMm = p.labelWidth;
      _labelHeightMm = p.labelHeight;
      _barcodeHeightMm = p.barcodeHeight;
      _barcodeWidthMm = p.barcodeWidth;
      _paperMarginMm = p.paperMargin;
      _labelMarginMm = p.labelMargin;
      _labelPaddingMm = p.labelPadding;
      _columnCount = p.columnCount;
      _fontSizeName = p.fontSizeName;
      _fontSizeBarcode = p.fontSizeBarcode;
      _fontSizePrice = p.fontSizePrice;

      _ctrlPaperW.text = _paperWidthMm.toString();
      _ctrlPaperH.text = _paperHeightMm.toString();
      _ctrlLabelW.text = _labelWidthMm.toString();
      _ctrlLabelH.text = _labelHeightMm.toString();
      _ctrlBarH.text = _barcodeHeightMm.toString();
      _ctrlBarW.text = _barcodeWidthMm.toString();
      _ctrlPaperM.text = _paperMarginMm.toString();
      _ctrlLabelM.text = _labelMarginMm.toString();
      _ctrlLabelP.text = _labelPaddingMm.toString();
      _ctrlCols.text = _columnCount.toString();
      _ctrlFntName.text = _fontSizeName.toString();
      _ctrlFntBar.text = _fontSizeBarcode.toString();
      _ctrlFntPrice.text = _fontSizePrice.toString();
    });
  }

  Future<void> _saveCurrentProfile() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan Profil Cetak'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama Profil', hintText: 'Misal: Label Thermal 40x30'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('SIMPAN')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.isNotEmpty) {
      final profile = PrintProfile(
        id: '',
        name: nameCtrl.text,
        paperWidth: _paperWidthMm,
        paperHeight: _paperHeightMm,
        labelWidth: _labelWidthMm,
        labelHeight: _labelHeightMm,
        barcodeHeight: _barcodeHeightMm,
        barcodeWidth: _barcodeWidthMm,
        paperMargin: _paperMarginMm,
        labelMargin: _labelMarginMm,
        labelPadding: _labelPaddingMm,
        columnCount: _columnCount,
        fontSizeName: _fontSizeName,
        fontSizeBarcode: _fontSizeBarcode,
        fontSizePrice: _fontSizePrice,
      );
      await ref.read(printProfilesProvider.notifier).saveProfile(profile);
      if (mounted) showSuccess(context, 'Profil berhasil disimpan');
    }
  }

  Future<void> _openExternalPdf(List<Product> allProducts) async {
    final productsToPrint = <MapEntry<Product, int>>[];
    for (final id in _selectedQuantities.keys) {
      try {
        final p = allProducts.firstWhere((element) => element.id == id);
        if (p.barcode != null && p.barcode!.isNotEmpty) {
          productsToPrint.add(MapEntry(p, _selectedQuantities[id]!));
        }
      } catch (_) {}
    }

    if (productsToPrint.isEmpty) {
      showError(context, 'Pilih setidaknya satu produk dengan barcode');
      return;
    }

    final doc = pw.Document();
    final List<Product> flatLabels = [];
    for (final entry in productsToPrint) {
      for (var i = 0; i < entry.value; i++) {
        flatLabels.add(entry.key);
      }
    }

    const double mmToPt = 2.83465;
    final paperFormat = PdfPageFormat(
      _paperWidthMm * mmToPt,
      _paperHeightMm * mmToPt,
      marginAll: _paperMarginMm * mmToPt,
    );

    final labelsPerPage = _columnCount * ((paperFormat.availableHeight / (_labelHeightMm * mmToPt)).floor());
    
    for (var i = 0; i < flatLabels.length; i += labelsPerPage) {
      final pageLabels = flatLabels.skip(i).take(labelsPerPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: paperFormat,
          build: (pw.Context context) {
            return pw.Wrap(
              spacing: _labelMarginMm * mmToPt,
              runSpacing: _labelMarginMm * mmToPt,
              children: pageLabels.map((p) => _buildPdfLabel(p, mmToPt, flatLabels.length)).toList(),
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/BuildEra_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);

    if (mounted) {
      await OpenFilex.open(file.path);
    }
  }

  pw.Widget _buildPdfLabel(Product p, double mmToPt, int totalCount) {
    // Standardize to TopCenter alignment as per last request
    const alignment = pw.Alignment.topCenter;
    const crossAlign = pw.CrossAxisAlignment.center;
    const textAlign = pw.TextAlign.center;

    // Use Code128 as it's the most compatible for any type of barcode string
    final bc = Barcode.code128();

    return pw.SizedBox(
      width: _labelWidthMm * mmToPt,
      height: _labelHeightMm * mmToPt,
      child: pw.Container(
        padding: pw.EdgeInsets.all(_labelPaddingMm * mmToPt),
        alignment: alignment,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          crossAxisAlignment: crossAlign,
          children: [
            // 1. Product Name
            pw.Text(
              p.name,
              textAlign: textAlign,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: _fontSizeName, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            
            // 2. Barcode
            pw.SizedBox(
              height: _barcodeHeightMm * mmToPt,
              width: _barcodeWidthMm * mmToPt,
              child: pw.BarcodeWidget(
                barcode: bc,
                data: p.barcode ?? '000000',
                drawText: false,
              ),
            ),
            
            // 3. Barcode Number
            pw.Text(
              p.barcode ?? '',
              style: pw.TextStyle(fontSize: _fontSizeBarcode, letterSpacing: 1),
            ),
            
            pw.SizedBox(height: 2),
            
            // 4. Price
            pw.Text(
              Formatters.currency(p.basePrice),
              style: pw.TextStyle(
                fontSize: _fontSizePrice, 
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700, // Price in Blue color
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          const PageHeader(title: 'Label Barcode', subtitle: 'Pilih produk dan atur tata letak cetak', icon: Icons.qr_code_2_rounded),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        color: AppTheme.surface,
                        child: Row(children: [
                          Expanded(child: AppSearchField(controller: _searchCtrl, hintText: 'Cari produk...', onChanged: (v) => setState(() => _search = v))),
                          const SizedBox(width: 16),
                          if (_selectedQuantities.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() => _selectedQuantities.clear()),
                              icon: const Icon(Icons.clear_all_rounded, size: 18),
                              label: const Text('Hapus Pilihan'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                            ),
                          const SizedBox(width: 16),
                          _sortDropdown(),
                          IconButton(onPressed: () => setState(() => _sortAsc = !_sortAsc), 
                            icon: Icon(_sortAsc ? Icons.south_rounded : Icons.north_rounded, color: AppTheme.accent)),
                        ]),
                      ),
                      Expanded(
                        child: productsAsync.when(
                          data: (products) {
                            var filtered = products.where((p) {
                              final q = _search.toLowerCase();
                              return p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false);
                            }).toList();

                            // Priority 1: Selected items first
                            // Priority 2: Sort criteria
                            filtered.sort((a, b) {
                              final aSel = _selectedQuantities.containsKey(a.id);
                              final bSel = _selectedQuantities.containsKey(b.id);
                              if (aSel != bSel) return aSel ? -1 : 1;

                              int cmp;
                              switch (_sortBy) {
                                case 'stock': cmp = a.stock.compareTo(b.stock); break;
                                case 'created': cmp = a.createdAt.compareTo(b.createdAt); break;
                                case 'updated': cmp = a.updatedAt.compareTo(b.updatedAt); break;
                                default: cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                              }
                              return _sortAsc ? cmp : -cmp;
                            });

                            return ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _ProductSelectionTile(
                                product: filtered[i],
                                isSelected: _selectedQuantities.containsKey(filtered[i].id),
                                qty: _selectedQuantities[filtered[i].id] ?? 0,
                                onToggle: () => _toggleSelect(filtered[i]),
                                onAdd: () => _updateQty(filtered[i].id, 1),
                                onRem: () => _updateQty(filtered[i].id, -1),
                              ),
                            );
                          },
                          loading: () => const AppLoading(),
                          error: (e, _) => Center(child: Text('Error: $e')),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 400,
                  decoration: const BoxDecoration(color: AppTheme.surface, border: Border(left: BorderSide(color: AppTheme.border))),
                  child: Column(
                    children: [
                      _settingsHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _section('Kertas (mm)', [
                                _field('Lebar', _ctrlPaperW, (v) => _paperWidthMm = v),
                                _field('Tinggi', _ctrlPaperH, (v) => _paperHeightMm = v),
                                _field('Margin', _ctrlPaperM, (v) => _paperMarginMm = v),
                              ]),
                              const Divider(height: 40),
                              _section('Label & Barcode (mm)', [
                                _field('Lebar Label', _ctrlLabelW, (v) => _labelWidthMm = v),
                                _field('Tinggi Label', _ctrlLabelH, (v) => _labelHeightMm = v),
                                _field('Lebar Barcode', _ctrlBarW, (v) => _barcodeWidthMm = v),
                                _field('Tinggi Barcode', _ctrlBarH, (v) => _barcodeHeightMm = v),
                                _field('Jarak Label', _ctrlLabelM, (v) => _labelMarginMm = v),
                                _field('Padding Label', _ctrlLabelP, (v) => _labelPaddingMm = v),
                                _field('Jumlah Kolom', _ctrlCols, (v) => _columnCount = v.toInt()),
                              ]),
                              const Divider(height: 40),
                              _section('Ukuran Font (pt)', [
                                _field('Nama Produk', _ctrlFntName, (v) => _fontSizeName = v),
                                _field('Nomor Barcode', _ctrlFntBar, (v) => _fontSizeBarcode = v),
                                _field('Harga Produk', _ctrlFntPrice, (v) => _fontSizePrice = v),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
                        child: SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () => productsAsync.whenData((p) => _openExternalPdf(p)),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('BUKA PDF & PRINT'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortDropdown() {
    return SizedBox(
      width: 160,
      height: 40,
      child: DropdownButtonFormField<String>(
        initialValue: _sortBy,
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        dropdownColor: AppTheme.surfaceAlt,
        items: const [
          DropdownMenuItem(value: 'name', child: Text('Nama (A-Z)')),
          DropdownMenuItem(value: 'stock', child: Text('Stok')),
          DropdownMenuItem(value: 'created', child: Text('Tgl Dibuat')),
          DropdownMenuItem(value: 'updated', child: Text('Tgl Diubah')),
        ],
        onChanged: (v) => setState(() => _sortBy = v!),
      ),
    );
  }

  Widget _settingsHeader() {
    final profiles = ref.watch(printProfilesProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 12),
            const Text('Konfigurasi Cetak', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: _saveCurrentProfile,
              icon: const Icon(Icons.save_rounded, size: 18, color: AppTheme.accent),
              tooltip: 'Simpan Profil',
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: DropdownButtonFormField<String?>(
              initialValue: profiles.any((p) => p.id == _selectedProfileId) ? _selectedProfileId : null,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Profil',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              dropdownColor: AppTheme.surfaceAlt,
              items: [
                const DropdownMenuItem(value: null, child: Text('Custom / Default')),
                ...profiles.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        onPressed: () => ref.read(printProfilesProvider.notifier).deleteProfile(p.id),
                        icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.danger),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                )),
              ],
              onChanged: (v) {
                if (v == null) {
                  setState(() => _selectedProfileId = null);
                } else {
                  final p = profiles.firstWhere((e) => e.id == v);
                  _loadProfile(p);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.accent, letterSpacing: 1)),
      const SizedBox(height: 16), ...children,
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        SizedBox(width: 70, child: TextField(controller: ctrl, textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null) setState(() => onChanged(d));
          },
        )),
      ]),
    );
  }
}

class _ProductSelectionTile extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final int qty;
  final VoidCallback onToggle, onAdd, onRem;

  const _ProductSelectionTile({required this.product, required this.isSelected, required this.qty, required this.onToggle, required this.onAdd, required this.onRem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border, width: isSelected ? 1.5 : 1),
      ),
      child: Row(children: [
        Checkbox(value: isSelected, onChanged: (_) => onToggle(), activeColor: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
          Text(product.barcode ?? 'Tanpa Barcode', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace')),
        ])),
        if (isSelected) ...[
          IconButton(onPressed: onRem, icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textSecondary)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.accent)),
        ],
      ]),
    );
  }
}
