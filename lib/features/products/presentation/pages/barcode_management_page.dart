import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/product_provider.dart';

import '../../models/print_profile.dart';
import '../../providers/print_profile_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../printing/printing.dart';

class BarcodeManagementPage extends ConsumerStatefulWidget {
  const BarcodeManagementPage({super.key});

  @override
  ConsumerState<BarcodeManagementPage> createState() =>
      _BarcodeManagementPageState();
}

class _BarcodeManagementPageState extends ConsumerState<BarcodeManagementPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _sortBy = 'name';
  bool _sortAsc = true;
  String? _selectedProfileId;
  bool _isRollMode = true;

  final Map<String, int> _selectedQuantities = {};

  // Settings with persistent controllers to avoid cursor jumping
  late final TextEditingController _ctrlPaperW,
      _ctrlPaperH,
      _ctrlLabelW,
      _ctrlLabelH,
      _ctrlBarH,
      _ctrlBarW,
      _ctrlPaperM,
      _ctrlLabelM,
      _ctrlLabelP,
      _ctrlCols;
  late final TextEditingController _ctrlFntName,
      _ctrlFntBar,
      _ctrlFntPrice,
      _ctrlFntStore;

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
  double _fontSizeStore = 7;

  @override
  void initState() {
    super.initState();
    _ctrlPaperW = TextEditingController(text: _paperWidthMm.toString());
    _ctrlPaperH = TextEditingController(text: _paperHeightMm.toString());
    _ctrlLabelW = TextEditingController(text: _labelWidthMm.toString());
    _ctrlLabelH = TextEditingController(text: _labelHeightMm.toString());
    _ctrlBarH = TextEditingController(text: _barcodeHeightMm.toString());
    _ctrlBarW = TextEditingController(text: _barcodeWidthMm.toString());
    _ctrlPaperM = TextEditingController(text: _paperMarginMm.toString());
    _ctrlLabelM = TextEditingController(text: _labelMarginMm.toString());
    _ctrlLabelP = TextEditingController(text: _labelPaddingMm.toString());
    _ctrlCols = TextEditingController(text: _columnCount.toString());
    _ctrlFntName = TextEditingController(text: _fontSizeName.toString());
    _ctrlFntBar = TextEditingController(text: _fontSizeBarcode.toString());
    _ctrlFntPrice = TextEditingController(text: _fontSizePrice.toString());
    _ctrlFntStore = TextEditingController(text: _fontSizeStore.toString());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctrlPaperW.dispose();
    _ctrlPaperH.dispose();
    _ctrlLabelW.dispose();
    _ctrlLabelH.dispose();
    _ctrlBarH.dispose();
    _ctrlBarW.dispose();
    _ctrlPaperM.dispose();
    _ctrlLabelM.dispose();
    _ctrlLabelP.dispose();
    _ctrlCols.dispose();
    _ctrlFntName.dispose();
    _ctrlFntBar.dispose();
    _ctrlFntPrice.dispose();
    _ctrlFntStore.dispose();
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

  void _updateQty(String id, int next) {
    setState(() {
      // Ensure minimum qty is 1 for selected items
      final finalQty = next < 1 ? 1 : next;
      _selectedQuantities[id] = finalQty;
    });
  }

  void _loadProfile(PrintProfile p) {
    setState(() {
      _selectedProfileId = p.id;
      _isRollMode = p.isRollMode;
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
      _fontSizeStore = p.fontSizeStoreName;

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
      _ctrlFntStore.text = _fontSizeStore.toString();
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
          decoration: const InputDecoration(
              labelText: 'Nama Profil', hintText: 'Misal: Label Thermal 40x30'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SIMPAN')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.isNotEmpty) {
      final profile = PrintProfile(
        id: '',
        name: nameCtrl.text,
        isRollMode: _isRollMode,
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
        fontSizeStoreName: _fontSizeStore,
      );
      await ref.read(printProfilesProvider.notifier).saveProfile(profile);
      if (mounted) showSuccess(context, 'Profil berhasil disimpan');
    }
  }

  Future<List<Map<String, dynamic>>> _buildLabelItems(
      List<Product> allProducts) async {
    final productsToPrint = <MapEntry<Product, int>>[];
    for (final id in _selectedQuantities.keys) {
      try {
        final qty = _selectedQuantities[id]!;
        // With minimum 1 logic, qty will be at least 1, but we keep the safety check
        if (qty <= 0) continue;

        final p = allProducts.firstWhere((element) => element.id == id);
        if (p.barcode != null && p.barcode!.isNotEmpty) {
          productsToPrint.add(MapEntry(p, qty));
        }
      } catch (_) {}
    }

    if (productsToPrint.isEmpty) {
      showError(context, 'Pilih setidaknya satu produk dengan barcode');
      return [];
    }

    final items = <Map<String, dynamic>>[];
    final settings = ref.read(settingsProvider);
    for (final entry in productsToPrint) {
      for (var i = 0; i < entry.value; i++) {
        items.add({
          'businessName': settings.businessName,
          'productName': entry.key.name,
          'barcode': entry.key.barcode ?? '',
          'price': 'Rp. ${entry.key.basePrice.toStringAsFixed(0)}',
        });
      }
    }

    return items;
  }

  Future<void> _printDirectly(List<Product> allProducts) async {
    final items = await _buildLabelItems(allProducts);
    if (items.isEmpty) return;

    final label = LabelDocument(
      title: 'LABEL',
      lines: const [],
      metadata: {
        'items': items,
        'isRollMode': _isRollMode,
        'labelWidthMm': _labelWidthMm,
        'labelHeightMm': _labelHeightMm,
        'horizontalGapMm': _labelMarginMm,
        'verticalGapMm': _labelMarginMm,
        'labelPaddingMm': _labelPaddingMm,
        'columns': _columnCount,
        'paperWidthMm': _paperWidthMm,
        'paperHeightMm': _paperHeightMm,
        'paperMarginMm': _paperMarginMm,
        'barcodeWidthMm': _barcodeWidthMm,
        'barcodeHeightMm': _barcodeHeightMm,
        'storeNameFontSize': _fontSizeStore,
        'productNameFontSize': _fontSizeName,
        'barcodeNumberFontSize': _fontSizeBarcode,
        'priceFontSize': _fontSizePrice,
      },
    );

    final result = await PrintOrchestrator().printLabel(
      label,
      const PrinterProfile(
        id: 'office-label',
        name: 'Office Label',
        transport: PrinterTransport.officePdf,
      ),
      settings: LabelTemplateSettings(
        labelWidthMm: _labelWidthMm,
        labelHeightMm: _labelHeightMm,
        horizontalGapMm: _labelMarginMm,
        verticalGapMm: _labelMarginMm,
        labelPaddingMm: _labelPaddingMm,
        columns: _columnCount,
        paperWidthMm: _paperWidthMm,
        paperHeightMm: _paperHeightMm,
        paperMarginMm: _paperMarginMm,
        barcodeWidthMm: _barcodeWidthMm,
        barcodeHeightMm: _barcodeHeightMm,
        storeNameFontSize: _fontSizeStore,
        productNameFontSize: _fontSizeName,
        barcodeNumberFontSize: _fontSizeBarcode,
        priceFontSize: _fontSizePrice,
      ),
    );

    if (result.bytes != null && result.bytes!.isNotEmpty) {
      final mmToPt = 2.83465;
      final rollWidth =
          (_labelWidthMm * _columnCount) + (_labelMarginMm * (_columnCount - 1));

      // Define the exact format to prevent OS scaling
      final format = PdfPageFormat(
        rollWidth * mmToPt,
        _labelHeightMm * mmToPt,
        marginAll: 0,
      );

      // We use layoutPdf but with a forced format constraint to hint the printer driver
      await Printing.layoutPdf(
        onLayout: (f) async => Uint8List.fromList(result.bytes!),
        format: _isRollMode ? format : PdfPageFormat.a4,
        name: 'BuildEra_Labels_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> _openExternalPdf(List<Product> allProducts) async {
    final items = await _buildLabelItems(allProducts);
    if (items.isEmpty) return;

    final label = LabelDocument(
      title: 'LABEL',
      lines: const [],
      metadata: {
        'items': items,
        'isRollMode': _isRollMode,
        'labelWidthMm': _labelWidthMm,
        'labelHeightMm': _labelHeightMm,
        'horizontalGapMm': _labelMarginMm,
        'verticalGapMm': _labelMarginMm,
        'labelPaddingMm': _labelPaddingMm,
        'columns': _columnCount,
        'paperWidthMm': _paperWidthMm,
        'paperHeightMm': _paperHeightMm,
        'paperMarginMm': _paperMarginMm,
        'barcodeWidthMm': _barcodeWidthMm,
        'barcodeHeightMm': _barcodeHeightMm,
        'storeNameFontSize': _fontSizeStore,
        'productNameFontSize': _fontSizeName,
        'barcodeNumberFontSize': _fontSizeBarcode,
        'priceFontSize': _fontSizePrice,
      },
    );

    final result = await PrintOrchestrator().printLabel(
      label,
      const PrinterProfile(
        id: 'office-label',
        name: 'Office Label',
        transport: PrinterTransport.officePdf,
      ),
      settings: LabelTemplateSettings(
        labelWidthMm: _labelWidthMm,
        labelHeightMm: _labelHeightMm,
        horizontalGapMm: _labelMarginMm,
        verticalGapMm: _labelMarginMm,
        labelPaddingMm: _labelPaddingMm,
        columns: _columnCount,
        paperWidthMm: _paperWidthMm,
        paperHeightMm: _paperHeightMm,
        paperMarginMm: _paperMarginMm,
        barcodeWidthMm: _barcodeWidthMm,
        barcodeHeightMm: _barcodeHeightMm,
        storeNameFontSize: _fontSizeStore,
        productNameFontSize: _fontSizeName,
        barcodeNumberFontSize: _fontSizeBarcode,
        priceFontSize: _fontSizePrice,
      ),
    );

    if (result.bytes != null && result.bytes!.isNotEmpty) {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/BuildEra_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(result.bytes!);

      if (mounted) {
        await OpenFilex.open(file.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          const PageHeader(
              title: 'Label Barcode',
              subtitle: 'Pilih produk dan atur tata letak cetak',
              icon: Icons.qr_code_2_rounded),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        color: AppTheme.surface,
                        child: Row(children: [
                          Expanded(
                              child: AppSearchField(
                                  controller: _searchCtrl,
                                  hintText: 'Cari produk...',
                                  onChanged: (v) =>
                                      setState(() => _search = v))),
                          const SizedBox(width: 16),
                          if (_selectedQuantities.isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedQuantities.clear()),
                              icon:
                                  const Icon(Icons.clear_all_rounded, size: 18),
                              label: const Text('Hapus Pilihan'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.danger),
                            ),
                          const SizedBox(width: 16),
                          _sortDropdown(),
                          IconButton(
                              onPressed: () =>
                                  setState(() => _sortAsc = !_sortAsc),
                              icon: Icon(
                                  _sortAsc
                                      ? Icons.south_rounded
                                      : Icons.north_rounded,
                                  color: AppTheme.accent)),
                        ]),
                      ),
                      Expanded(
                        child: productsAsync.when(
                          data: (products) {
                            var filtered = products.where((p) {
                              final q = _search.toLowerCase();
                              return p.name.toLowerCase().contains(q) ||
                                  (p.barcode?.contains(q) ?? false);
                            }).toList();

                            // Priority 1: Selected items first
                            // Priority 2: Sort criteria
                            filtered.sort((a, b) {
                              final aSel =
                                  _selectedQuantities.containsKey(a.id);
                              final bSel =
                                  _selectedQuantities.containsKey(b.id);
                              if (aSel != bSel) return aSel ? -1 : 1;

                              int cmp;
                              switch (_sortBy) {
                                case 'stock':
                                  cmp = a.stock.compareTo(b.stock);
                                  break;
                                case 'created':
                                  cmp = a.createdAt.compareTo(b.createdAt);
                                  break;
                                case 'updated':
                                  cmp = a.updatedAt.compareTo(b.updatedAt);
                                  break;
                                default:
                                  cmp = a.name
                                      .toLowerCase()
                                      .compareTo(b.name.toLowerCase());
                              }
                              return _sortAsc ? cmp : -cmp;
                            });

                            return ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) =>
                                  _ProductSelectionTile(
                                product: filtered[i],
                                isSelected: _selectedQuantities
                                    .containsKey(filtered[i].id),
                                qty: _selectedQuantities[filtered[i].id] ?? 0,
                                onToggle: () => _toggleSelect(filtered[i]),
                                onQtyChanged: (v) =>
                                    _updateQty(filtered[i].id, v),
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
                  decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(left: BorderSide(color: AppTheme.border))),
                  child: Column(
                    children: [
                      _settingsHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModeIllustration(),
                              const SizedBox(height: 24),
                              _buildModeSwitch(),
                              const Divider(height: 40),
                              if (!_isRollMode) ...[
                                _section('Kertas (mm)', [
                                  _field('Lebar', _ctrlPaperW,
                                      (v) => _paperWidthMm = v),
                                  _field('Tinggi', _ctrlPaperH,
                                      (v) => _paperHeightMm = v),
                                  _field('Margin', _ctrlPaperM,
                                      (v) => _paperMarginMm = v),
                                ]),
                                const Divider(height: 40),
                              ],
                              _section('Label & Barcode (mm)', [
                                _field('Lebar Label', _ctrlLabelW,
                                    (v) => _labelWidthMm = v),
                                _field('Tinggi Label', _ctrlLabelH,
                                    (v) => _labelHeightMm = v),
                                _field('Lebar Barcode', _ctrlBarW,
                                    (v) => _barcodeWidthMm = v),
                                _field('Tinggi Barcode', _ctrlBarH,
                                    (v) => _barcodeHeightMm = v),
                                _field(
                                    _isRollMode ? 'Jarak (Gap)' : 'Jarak Label',
                                    _ctrlLabelM,
                                    (v) => _labelMarginMm = v),
                                _field('Padding Label', _ctrlLabelP,
                                    (v) => _labelPaddingMm = v),
                                _field('Jumlah Kolom', _ctrlCols,
                                    (v) => _columnCount = v.toInt()),
                              ]),
                              const Divider(height: 40),
                              _section('Ukuran Font (pt)', [
                                _field('Nama Toko', _ctrlFntStore,
                                    (v) => _fontSizeStore = v),
                                _field('Nama Produk', _ctrlFntName,
                                    (v) => _fontSizeName = v),
                                _field('Nomor Barcode', _ctrlFntBar,
                                    (v) => _fontSizeBarcode = v),
                                _field('Harga Produk', _ctrlFntPrice,
                                    (v) => _fontSizePrice = v),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: AppTheme.border))),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => productsAsync
                                    .whenData((p) => _printDirectly(p)),
                                icon: const Icon(Icons.print_rounded),
                                label: const Text('CETAK LANGSUNG'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: OutlinedButton.icon(
                                onPressed: () => productsAsync
                                    .whenData((p) => _openExternalPdf(p)),
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('BUKA PDF'),
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
        isExpanded: true,
        decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 12),
            const Text('Konfigurasi Cetak',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: _saveCurrentProfile,
              icon: const Icon(Icons.save_rounded,
                  size: 18, color: AppTheme.accent),
              tooltip: 'Simpan Profil',
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: DropdownButtonFormField<String?>(
              initialValue: profiles.any((p) => p.id == _selectedProfileId)
                  ? _selectedProfileId
                  : null,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Profil',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              dropdownColor: AppTheme.surfaceAlt,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Custom / Default')),
                ...profiles.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                            onPressed: () => ref
                                .read(printProfilesProvider.notifier)
                                .deleteProfile(p.id),
                            icon: const Icon(Icons.delete_outline,
                                size: 14, color: AppTheme.danger),
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
      Text(title,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppTheme.accent,
              letterSpacing: 1)),
      const SizedBox(height: 16),
      ...children,
    ]);
  }

  Widget _field(String label, TextEditingController ctrl,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary))),
        SizedBox(
            width: 70,
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8)),
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null) setState(() => onChanged(d));
              },
            )),
      ]),
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isRollMode
            ? AppTheme.accent.withValues(alpha: 0.1)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: _isRollMode ? AppTheme.accent : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
              _isRollMode
                  ? Icons.settings_input_component_rounded
                  : Icons.description_rounded,
              color: _isRollMode ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode Printer Roll',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Satu label per halaman PDF',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isRollMode,
            onChanged: (v) => setState(() => _isRollMode = v),
            activeTrackColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildModeIllustration() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: CustomPaint(
        painter: _BarcodeModePainter(isRoll: _isRollMode),
      ),
    );
  }
}

class _BarcodeModePainter extends CustomPainter {
  final bool isRoll;
  _BarcodeModePainter({required this.isRoll});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isRoll) {
      // Draw Roll
      final centerX = size.width / 2;
      final centerY = size.height / 2;

      // Roll circle
      canvas.drawCircle(Offset(centerX - 40, centerY), 30, paint);
      canvas.drawCircle(Offset(centerX - 40, centerY), 10, paint);

      // Paper coming out
      final path = Path()
        ..moveTo(centerX - 40, centerY - 30)
        ..lineTo(centerX + 60, centerY - 30)
        ..lineTo(centerX + 60, centerY + 30)
        ..lineTo(centerX - 40, centerY + 30);
      canvas.drawPath(path, paint);

      // Labels
      final labelPaint = Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromLTRBR(centerX - 10, centerY - 20, centerX + 15,
              centerY + 20, const Radius.circular(2)),
          labelPaint);
      canvas.drawRRect(
          RRect.fromLTRBR(centerX + 25, centerY - 20, centerX + 50,
              centerY + 20, const Radius.circular(2)),
          labelPaint);
    } else {
      // Draw Sheet (A4)
      final rect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 70,
          height: 90);
      canvas.drawRect(rect, paint);

      // Grid of labels
      final labelPaint = Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 2; x++) {
          canvas.drawRRect(
              RRect.fromLTRBR(
                  rect.left + 10 + (x * 30),
                  rect.top + 10 + (y * 25),
                  rect.left + 30 + (x * 30),
                  rect.top + 30 + (y * 25),
                  const Radius.circular(2)),
              labelPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ProductSelectionTile extends StatefulWidget {
  final Product product;
  final bool isSelected;
  final int qty;
  final VoidCallback onToggle;
  final ValueChanged<int> onQtyChanged;

  const _ProductSelectionTile(
      {required this.product,
      required this.isSelected,
      required this.qty,
      required this.onToggle,
      required this.onQtyChanged});

  @override
  State<_ProductSelectionTile> createState() => _ProductSelectionTileState();
}

class _ProductSelectionTileState extends State<_ProductSelectionTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.qty > 0 ? widget.qty.toString() : '');
  }

  @override
  void didUpdateWidget(_ProductSelectionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.qty != oldWidget.qty) {
      final text = widget.qty > 0 ? widget.qty.toString() : '';
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.isSelected ? AppTheme.accent : AppTheme.border,
            width: widget.isSelected ? 1.5 : 1),
      ),
      child: Row(children: [
        Checkbox(
            value: widget.isSelected,
            onChanged: (_) => widget.onToggle(),
            activeColor: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis),
          Text(widget.product.barcode ?? 'Tanpa Barcode',
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace')),
        ])),
        if (widget.isSelected) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                hintText: 'Qty',
                suffixText: 'pcs',
                suffixStyle:
                    const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) {
                // If user clears the field or types 0, we send 0 to the update method
                // which will handle resetting it to 1.
                final val = int.tryParse(v) ?? 0;
                widget.onQtyChanged(val);
              },
            ),
          ),
        ],
      ]),
    );
  }
}
