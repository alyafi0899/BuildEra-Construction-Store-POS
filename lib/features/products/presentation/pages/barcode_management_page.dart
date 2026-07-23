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

  Future<void> _generatePdf(List<Product> allProducts) async {
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
      showError(context, 'Pilih produk untuk dicetak');
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
              children: pageLabels.map((p) => _buildPdfLabel(p, mmToPt)).toList(),
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

  pw.Widget _buildPdfLabel(Product p, double mmToPt) {
    final bc = Barcode.code128();
    return pw.SizedBox(
      width: _labelWidthMm * mmToPt,
      height: _labelHeightMm * mmToPt,
      child: pw.Container(
        padding: pw.EdgeInsets.all(_labelPaddingMm * mmToPt),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(p.name, style: pw.TextStyle(fontSize: _fontSizeName, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center, maxLines: 2),
            pw.SizedBox(height: 2),
            pw.SizedBox(
              height: _barcodeHeightMm * mmToPt,
              width: _barcodeWidthMm * mmToPt,
              child: pw.BarcodeWidget(barcode: bc, data: p.barcode ?? '000000', drawText: false),
            ),
            pw.Text(p.barcode ?? '', style: pw.TextStyle(fontSize: _fontSizeBarcode)),
            pw.SizedBox(height: 2),
            pw.Text(Formatters.currency(p.basePrice), style: pw.TextStyle(fontSize: _fontSizePrice, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          const PageHeader(
            title: 'Label Barcode',
            subtitle: 'Atur dan cetak label produk',
            icon: Icons.qr_code_2_rounded,
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Cari produk...',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => productsAsync.whenData((p) => _generatePdf(p)),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Cetak Label'),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: productsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = products.where((p) {
                  final q = _search.toLowerCase();
                  return p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false);
                }).toList();

                if (filtered.isEmpty) return const EmptyState(icon: Icons.search_off, title: 'Produk tidak ditemukan');

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final isSelected = _selectedQuantities.containsKey(p.id);
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : null,
                      child: Row(
                        children: [
                          Checkbox(value: isSelected, onChanged: (_) => _toggleSelect(p)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(p.barcode ?? 'Tanpa Barcode', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Row(
                              children: [
                                _qtyBtn(Icons.remove, () => _updateQty(p.id, -1)),
                                Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  child: Text('${_selectedQuantities[p.id]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                _qtyBtn(Icons.add, () => _updateQty(p.id, 1)),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'settings',
            onPressed: () => _showSettingsSheet(context),
            backgroundColor: AppTheme.surfaceAlt,
            child: const Icon(Icons.tune_rounded, color: AppTheme.primary),
          ),
          if (isMobile && _selectedQuantities.isNotEmpty) ...[
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'print',
              onPressed: () => productsAsync.whenData((p) => _generatePdf(p)),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              label: const Text('Cetak Label', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 16),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('Konfigurasi Cetak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(onPressed: _saveCurrentProfile, icon: const Icon(Icons.save_rounded, color: AppTheme.primary)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _profilePicker(setSheetState),
                  const SizedBox(height: 24),
                  _sheetSection('Ukuran Kertas (mm)', [
                    _sheetField('Lebar', _ctrlPaperW, (v) => _paperWidthMm = v),
                    _sheetField('Tinggi', _ctrlPaperH, (v) => _paperHeightMm = v),
                    _sheetField('Margin', _ctrlPaperM, (v) => _paperMarginMm = v),
                  ]),
                  const SizedBox(height: 24),
                  _sheetSection('Label & Barcode (mm)', [
                    _sheetField('Lebar Label', _ctrlLabelW, (v) => _labelWidthMm = v),
                    _sheetField('Tinggi Label', _ctrlLabelH, (v) => _labelHeightMm = v),
                    _sheetField('Tinggi Barcode', _ctrlBarH, (v) => _barcodeHeightMm = v),
                    _sheetField('Jumlah Kolom', _ctrlCols, (v) => _columnCount = v.toInt()),
                  ]),
                  const SizedBox(height: 24),
                  _sheetSection('Ukuran Font (pt)', [
                    _sheetField('Nama Produk', _ctrlFntName, (v) => _fontSizeName = v),
                    _sheetField('Barcode', _ctrlFntBar, (v) => _fontSizeBarcode = v),
                    _sheetField('Harga', _ctrlFntPrice, (v) => _fontSizePrice = v),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilePicker(StateSetter setSheetState) {
    final profiles = ref.watch(printProfilesProvider);
    return DropdownButtonFormField<String?>(
      value: profiles.any((p) => p.id == _selectedProfileId) ? _selectedProfileId : null,
      decoration: const InputDecoration(labelText: 'Profil Cetak'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Default')),
        ...profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
      ],
      onChanged: (v) {
        if (v == null) {
          setState(() => _selectedProfileId = null);
        } else {
          final p = profiles.firstWhere((e) => e.id == v);
          _loadProfile(p);
          setSheetState(() {});
        }
      },
    );
  }

  Widget _sheetSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null) {
                  onChanged(d);
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
