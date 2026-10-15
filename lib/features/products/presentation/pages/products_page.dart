import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../../core/utils/barcode_helper.dart';
import '../../../../shared/widgets/product_detail_dialog.dart';
import '../../providers/barcode_history_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/entity_provider.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/excel_import_dialog.dart';
import '../../models/product_financials.dart';
import '../../../inventory/providers/restock_provider.dart';
import '../../../inventory/models/restock_record.dart';
import '../../../inventory/presentation/widgets/restock_dialog.dart';
import '../../../../shared/widgets/security_gate.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../features/settings/providers/settings_provider.dart';
import '../../../../core/localization/localization_provider.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isGenerating = false;
  bool _selectionMode = false;
  bool _showSupplierColumn = true;
  bool _showCostColumn = true;
  bool _showStats = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelectAll(List<Product> products) {
    setState(() {
      final allVisibleSelected =
          products.every((p) => _selectedIds.contains(p.id));
      if (allVisibleSelected) {
        for (final p in products) {
          _selectedIds.remove(p.id);
        }
      } else {
        for (final p in products) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
        _selectionMode = true;
      }
    });
  }

  void _startSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(context,
        title: 'Hapus Massal',
        content:
            'Yakin hapus $count produk terpilih? Data tidak dapat dipulihkan.');

    if (!mounted) return;
    if (ok) {
      try {
        await ref
            .read(productsActionProvider)
            .deleteProductsBatch(_selectedIds.toList());
        setState(() {
          _selectedIds.clear();
          _selectionMode = false;
        });
        if (mounted) showSuccess(context, '$count produk dihapus');
      } catch (e) {
        if (mounted) showError(context, 'Gagal menghapus produk: $e');
      }
    }
  }

  Future<void> _generateMissingBarcodes(List<Product> allProducts) async {
    final missing = allProducts
        .where((p) => p.barcode == null || p.barcode!.isEmpty)
        .toList();
    if (missing.isEmpty) {
      showSuccess(context, 'Semua produk sudah memiliki barcode.');
      return;
    }

    final ok = await showConfirmDialog(context,
        title: 'Generate Barcode Massal',
        content:
            'Akan membuat barcode unik untuk ${missing.length} produk. Lanjutkan?',
        confirmLabel: 'Generate',
        confirmColor: AppTheme.accent);

    if (!mounted || !ok) return;

    setState(() => _isGenerating = true);

    try {
      final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
      final productsAction = ref.read(productsActionProvider);
      final List<Product> updatedProducts = [];

      for (final product in missing) {
        String newBarcode = '';
        bool isUnique = false;
        int attempts = 0;

        while (!isUnique && attempts < 15) {
          final rawData = BarcodeHelper.generateRandomEAN13Data();
          newBarcode = BarcodeHelper.getEAN13WithCheckDigit(rawData);
          final used = await historyRepo.isBarcodeUsed(newBarcode);
          // Also check in our current batch to avoid duplicate within the same generation
          final duplicateInBatch =
              updatedProducts.any((p) => p.barcode == newBarcode);

          if (!used && !duplicateInBatch) isUnique = true;
          attempts++;
        }

        if (isUnique) {
          updatedProducts.add(product.copyWith(barcode: newBarcode));
        }
      }

      if (updatedProducts.isNotEmpty) {
        await productsAction.updateProductsBatch(updatedProducts);
        if (mounted) {
          showSuccess(context,
              'Berhasil membuat ${updatedProducts.length} barcode baru.');
        }
      } else {
        if (mounted) {
          showError(context, 'Tidak ada barcode unik yang berhasil dibuat.');
        }
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal generate barcode: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportToExcel(List<Product> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Fetch entities for lookup
      final suppliers = await ref.read(suppliersProvider.future);
      final shipping = await ref.read(shippingServicesProvider.future);

      final supplierMap = {for (var s in suppliers) s.name: s};
      final shippingMap = {for (var s in shipping) s.name: s};

      // Header row matching the import format + metadata
      sheet.appendRow([
        TextCellValue('Nama Produk'), // A
        TextCellValue('Barcode'), // B
        TextCellValue('Kategori'), // C
        TextCellValue('Satuan Dasar'), // D
        TextCellValue('Stok Awal'), // E
        TextCellValue('Harga Modal (Rp)'), // F
        TextCellValue('Harga Jual Dasar (Rp)'), // G
        TextCellValue('Nama Supplier'), // H
        TextCellValue('No HP Supplier'), // I
        TextCellValue('Alamat Supplier'), // J
        TextCellValue('Nama Expedisi'), // K
        TextCellValue('No HP Expedisi'), // L
        TextCellValue('Alamat Expedisi'), // M
        TextCellValue('Tanggal Dibuat'), // N
        TextCellValue('Terakhir Diubah'), // O
      ]);

      // Data rows
      for (final p in products) {
        final sName = p.financials.supplierName;
        final s = sName != null ? supplierMap[sName] : null;
        final shName = p.financials.shippingServiceName;
        final sh = shName != null ? shippingMap[shName] : null;

        sheet.appendRow([
          TextCellValue(p.name),
          TextCellValue(p.barcode ?? ''),
          TextCellValue(p.category),
          TextCellValue(p.baseUnit),
          DoubleCellValue(p.stock),
          DoubleCellValue(p.costPrice),
          DoubleCellValue(p.basePrice),
          TextCellValue(sName ?? ''),
          TextCellValue(s?.phone ?? ''),
          TextCellValue(s?.address ?? ''),
          TextCellValue(shName ?? ''),
          TextCellValue(sh?.phone ?? ''),
          TextCellValue(''), // Expedition Address (not currently in model)
          TextCellValue(Formatters.dateTime(p.createdAt)),
          TextCellValue(Formatters.dateTime(p.updatedAt)),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final now = DateTime.now();
      final fileName =
          'Backup_Produk_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );

      if (mounted) showSuccess(context, 'Backup berhasil diekspor');
    } catch (e) {
      if (mounted) showError(context, 'Gagal ekspor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final sortedProducts = ref.watch(sortedProductsProvider);
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final sort = ref.watch(productSortProvider);
    final filters = ref.watch(productFiltersProvider);

    // Reset search when navigating back to this page
    ref.listen(navigationIndexProvider, (prev, next) {
      if (next == 1) {
        // Index of ProductsPage in MainShell
        _searchCtrl.clear();
        ref.read(productSearchQueryProvider.notifier).set('');
      }
    });

    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactLayout =
              ResponsiveBreakpoints.useCompactManagementLayout(
                  constraints.maxWidth);
          return PinGate(
            manualTrigger: ref.watch(settingsProvider).lockProductsPage,
            child: Column(
              children: [
                // Top bar
                PageHeader(
                  title: strings.productsTitle,
                  subtitle: strings.isEnglish ? 'Manage product list and selling units' : 'Kelola daftar produk dan satuan jual',
                  icon: Icons.inventory_2_rounded,
                  actions: compactLayout
                      ? [
                          IconButton(
                            onPressed: () =>
                                setState(() => _showStats = !_showStats),
                            icon: Icon(_showStats
                                ? Icons.analytics
                                : Icons.analytics_outlined),
                            color: _showStats
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            tooltip: _showStats
                                ? 'Sembunyikan Ringkasan Stok'
                                : 'Tampilkan Ringkasan Stok',
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Aksi lainnya',
                            onSelected: (value) {
                              switch (value) {
                                case 'generate':
                                  if (!_isGenerating) {
                                    productsAsync
                                        .whenData(_generateMissingBarcodes);
                                  }
                                case 'import':
                                  ExcelImportDialog.show(context);
                                case 'export':
                                  productsAsync.whenData(_exportToExcel);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'generate',
                                enabled: !_isGenerating,
                                child: ListTile(
                                  leading: _isGenerating
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.auto_fix_high_rounded),
                                  title: const Text('Generate barcode kosong'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'import',
                                child: const ListTile(
                                  leading: Icon(Icons.file_upload_outlined),
                                  title: Text('Import Excel'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'export',
                                child: const ListTile(
                                  leading: Icon(Icons.file_download_outlined),
                                  title: Text('Export Excel'),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => ProductFormDialog.show(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah'),
                          ),
                        ]
                      : [
                          if (_isGenerating)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.accent),
                                ),
                                SizedBox(width: 12),
                                Text('Generating Barcodes...'),
                              ],
                            ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showStats = !_showStats),
                            icon: Icon(
                                _showStats
                                    ? Icons.analytics_outlined
                                    : Icons.analytics_rounded,
                                size: 18),
                            label: Text(_showStats
                                ? 'Sembunyikan Ringkasan'
                                : 'Ringkasan SKU'),
                            style: _showStats
                                ? OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accent,
                                    side: const BorderSide(
                                        color: AppTheme.accent),
                                  )
                                : null,
                          ),
                          OutlinedButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : () => productsAsync.whenData(
                                      _generateMissingBarcodes,
                                    ),
                            icon: const Icon(Icons.auto_fix_high_rounded,
                                size: 18),
                            label: const Text('Generate Missing'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => ExcelImportDialog.show(context),
                            icon: const Icon(Icons.file_upload_outlined,
                                size: 18),
                            label: const Text('Import Excel'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                productsAsync.whenData(_exportToExcel),
                            icon: const Icon(Icons.file_download_outlined,
                                size: 18),
                            label: const Text('Export Excel'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => ProductFormDialog.show(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah Produk'),
                          ),
                        ],
                ),

                // Stats row
                if (_showStats)
                  productsAsync.when(
                    loading: () => const SizedBox(height: 100),
                  error: (_, __) => const SizedBox(),
                  data: (products) {
                    final lowStock = products.where((p) => p.isLowStock).length;
                    final totalSKU = products.length;
                    final outOfStock =
                        products.where((p) => p.stock <= 0).length;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600
                            ? 3
                            : constraints.maxWidth < 390
                                ? 1
                                : 2;
                        final horizontalPadding = compactLayout ? 12.0 : 24.0;
                        final contentWidth =
                            constraints.maxWidth - horizontalPadding * 2;
                        final cardWidth =
                            (contentWidth - (columns - 1) * 12) / columns;
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: compactLayout ? 12 : 24,
                              vertical: 16),
                          color: AppTheme.surface,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                    label: 'Total SKU',
                                    value: totalSKU.toString(),
                                    icon: Icons.inventory_2_rounded),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                    label: 'Stok Rendah',
                                    value: lowStock.toString(),
                                    icon: Icons.warning_amber_rounded,
                                    accentColor: AppTheme.warning),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                    label: 'Habis',
                                    value: outOfStock.toString(),
                                    icon: Icons.remove_shopping_cart_rounded,
                                    accentColor: AppTheme.danger),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                // Filters & Sorting
                Container(
                  padding: EdgeInsets.fromLTRB(
                      compactLayout ? 12 : 24, 12, compactLayout ? 12 : 24, 12),
                  color: AppTheme.surface,
                  child: Column(
                    children: [
                      if (!compactLayout)
                        Row(children: [
                          SizedBox(
                            width: 260,
                            child: AppSearchField(
                              controller: _searchCtrl,
                              hintText: 'Cari produk atau barcode...',
                              onChanged: (v) => ref
                                  .read(productSearchQueryProvider.notifier)
                                  .set(v),
                              onClear: () {
                                _searchCtrl.clear();
                                ref
                                    .read(productSearchQueryProvider.notifier)
                                    .set('');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 160,
                            height: 48,
                            child: DropdownButtonFormField<String?>(
                              initialValue: categoryFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Kategori', isDense: true),
                              dropdownColor: AppTheme.surfaceAlt,
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Semua Kategori')),
                                ...AppConstants.categories.map((c) =>
                                    DropdownMenuItem(
                                        value: c,
                                        child: Text(c,
                                            overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (v) => ref
                                  .read(productCategoryFilterProvider.notifier)
                                  .set(v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 160,
                            height: 48,
                            child: DropdownButtonFormField<ProductSortField>(
                              initialValue: sort.field,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Urutkan', isDense: true),
                              dropdownColor: AppTheme.surfaceAlt,
                              items: const [
                                DropdownMenuItem(
                                    value: ProductSortField.name,
                                    child: Text('Nama (A-Z)')),
                                DropdownMenuItem(
                                    value: ProductSortField.category,
                                    child: Text('Kategori')),
                                DropdownMenuItem(
                                    value: ProductSortField.stock,
                                    child: Text('Stok')),
                                DropdownMenuItem(
                                    value: ProductSortField.cost,
                                    child: Text('Harga Modal')),
                                DropdownMenuItem(
                                    value: ProductSortField.price,
                                    child: Text('Harga Jual')),
                                DropdownMenuItem(
                                    value: ProductSortField.profit,
                                    child: Text('Profit Satuan')),
                                DropdownMenuItem(
                                    value: ProductSortField.created,
                                    child: Text('Tanggal Dibuat')),
                                DropdownMenuItem(
                                    value: ProductSortField.updated,
                                    child: Text('Terakhir Diubah')),
                              ],
                              onChanged: (v) => ref
                                  .read(productSortProvider.notifier)
                                  .setField(v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => ref
                                .read(productSortProvider.notifier)
                                .toggleOrder(),
                            icon: Icon(
                                sort.ascending
                                    ? Icons.south_rounded
                                    : Icons.north_rounded,
                                color: AppTheme.accent),
                            tooltip:
                                sort.ascending ? 'Ascending' : 'Descending',
                          ),
                          _columnVisibilityMenu(),
                          const SizedBox(width: 16),
                          if (_selectedIds.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: _bulkDelete,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.danger),
                              icon: const Icon(Icons.delete_sweep_rounded,
                                  size: 18),
                              label: Text('Hapus (${_selectedIds.length})'),
                            ),
                          const Spacer(),
                          productsAsync.when(
                            data: (p) => Text('${p.length} produk',
                                style: Theme.of(context).textTheme.bodySmall),
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                          ),
                        ])
                      else
                        Column(
                          children: [
                            AppSearchField(
                              controller: _searchCtrl,
                              hintText: 'Cari produk atau barcode...',
                              onChanged: (v) => ref
                                  .read(productSearchQueryProvider.notifier)
                                  .set(v),
                              onClear: () {
                                _searchCtrl.clear();
                                ref
                                    .read(productSearchQueryProvider.notifier)
                                    .set('');
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: categoryFilter,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Kategori', isDense: true),
                                    dropdownColor: AppTheme.surfaceAlt,
                                    items: [
                                      const DropdownMenuItem(
                                          value: null, child: Text('Semua')),
                                      ...AppConstants.categories.map((c) =>
                                          DropdownMenuItem(
                                              value: c,
                                              child: Text(c,
                                                  overflow:
                                                      TextOverflow.ellipsis))),
                                    ],
                                    onChanged: (v) => ref
                                        .read(productCategoryFilterProvider
                                            .notifier)
                                        .set(v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child:
                                      DropdownButtonFormField<ProductSortField>(
                                    initialValue: sort.field,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Urutkan', isDense: true),
                                    dropdownColor: AppTheme.surfaceAlt,
                                    items: const [
                                      DropdownMenuItem(
                                          value: ProductSortField.name,
                                          child: Text('Nama (A-Z)')),
                                      DropdownMenuItem(
                                          value: ProductSortField.category,
                                          child: Text('Kategori')),
                                      DropdownMenuItem(
                                          value: ProductSortField.stock,
                                          child: Text('Stok')),
                                      DropdownMenuItem(
                                          value: ProductSortField.cost,
                                          child: Text('Harga Modal')),
                                      DropdownMenuItem(
                                          value: ProductSortField.price,
                                          child: Text('Harga Jual')),
                                      DropdownMenuItem(
                                          value: ProductSortField.profit,
                                          child: Text('Profit Satuan')),
                                      DropdownMenuItem(
                                          value: ProductSortField.created,
                                          child: Text('Tanggal Dibuat')),
                                      DropdownMenuItem(
                                          value: ProductSortField.updated,
                                          child: Text('Terakhir Diubah')),
                                    ],
                                    onChanged: (v) => ref
                                        .read(productSortProvider.notifier)
                                        .setField(v!),
                                  ),
                                ),
                                IconButton(
                                  tooltip: sort.ascending
                                      ? 'Ascending'
                                      : 'Descending',
                                  onPressed: () => ref
                                      .read(productSortProvider.notifier)
                                      .toggleOrder(),
                                  icon: Icon(
                                      sort.ascending
                                          ? Icons.south_rounded
                                          : Icons.north_rounded,
                                      color: AppTheme.accent),
                                ),
                                _columnVisibilityMenu(),
                              ],
                            ),
                            Row(
                              children: [
                                if (_selectionMode)
                                  Text('${_selectedIds.length} dipilih',
                                      style:
                                          Theme.of(context).textTheme.bodySmall)
                                else
                                  const Text('Tekan lama produk untuk memilih',
                                      style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11)),
                                productsAsync.when(
                                  data: (p) => Text('${p.length} produk',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                ),
                                const Spacer(),
                                if (_selectedIds.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _bulkDelete,
                                    icon:
                                        const Icon(Icons.delete_sweep_rounded),
                                    label:
                                        Text('Hapus (${_selectedIds.length})'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.danger),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          const Icon(Icons.filter_list_rounded,
                              size: 18, color: AppTheme.textMuted),
                          const SizedBox(width: 12),
                          const _FilterLabel('Stok:'),
                          _FilterTab(
                              label: 'Semua',
                              selected: filters.stock == 'all',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setStock('all')),
                          _FilterTab(
                              label: 'Tersedia',
                              selected: filters.stock == 'in',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setStock('in')),
                          _FilterTab(
                              label: 'Rendah',
                              selected: filters.stock == 'low',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setStock('low')),
                          _FilterTab(
                              label: 'Habis',
                              selected: filters.stock == 'out',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setStock('out')),
                          const SizedBox(width: 24),
                          const _FilterLabel('Bayar Supplier:'),
                          _FilterTab(
                              label: 'Semua',
                              selected: filters.supplier == 'all',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setSupplier('all')),
                          _FilterTab(
                              label: 'Lunas',
                              selected: filters.supplier == 'paid',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setSupplier('paid')),
                          _FilterTab(
                              label: 'Belum',
                              selected: filters.supplier == 'unpaid',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setSupplier('unpaid')),
                          const SizedBox(width: 24),
                          const _FilterLabel('Bayar Ongkir:'),
                          _FilterTab(
                              label: 'Semua',
                              selected: filters.shipping == 'all',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setShipping('all')),
                          _FilterTab(
                              label: 'Lunas',
                              selected: filters.shipping == 'paid',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setShipping('paid')),
                          _FilterTab(
                              label: 'Belum',
                              selected: filters.shipping == 'unpaid',
                              onTap: () => ref
                                  .read(productFiltersProvider.notifier)
                                  .setShipping('unpaid')),
                        ]),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: sortedProducts.isEmpty && productsAsync.isLoading
                      ? const AppLoading()
                      : sortedProducts.isEmpty
                          ? const EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Tidak ada produk',
                              subtitle:
                                  'Tambah produk pertama Anda atau sesuaikan filter',
                            )
                          : _ProductTable(
                              compactLayout: compactLayout,
                              selectionMode: _selectionMode,
                              showSupplierColumn: _showSupplierColumn,
                              showCostColumn: _showCostColumn,
                              products: sortedProducts,
                              selectedIds: _selectedIds,
                              onToggleSelect: _toggleSelect,
                              onLongPressSelect: _startSelection,
                              onSelectAll: () =>
                                  _toggleSelectAll(sortedProducts),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _columnVisibilityMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Tampilkan/sembunyikan kolom',
      icon:
          const Icon(Icons.view_column_rounded, color: AppTheme.textSecondary),
      onSelected: (column) {
        setState(() {
          if (column == 'supplier') {
            _showSupplierColumn = !_showSupplierColumn;
          } else {
            _showCostColumn = !_showCostColumn;
          }
        });
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem<String>(
          value: 'supplier',
          checked: _showSupplierColumn,
          child: const Text('Supplier / Ongkir'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'cost',
          checked: _showCostColumn,
          child: const Text('Harga Modal'),
        ),
      ],
    );
  }
}

class _ProductTable extends StatefulWidget {
  final List<Product> products;
  final bool compactLayout;
  final bool selectionMode;
  final bool showSupplierColumn;
  final bool showCostColumn;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onLongPressSelect;
  final VoidCallback onSelectAll;

  const _ProductTable({
    required this.compactLayout,
    required this.selectionMode,
    required this.showSupplierColumn,
    required this.showCostColumn,
    required this.products,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onLongPressSelect,
    required this.onSelectAll,
  });

  @override
  State<_ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<_ProductTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compactLayout) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: widget.products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = widget.products[index];
          return _CompactProductCard(
            key: ValueKey('compact_prod_${product.id}'),
            product: product,
            selected: widget.selectedIds.contains(product.id),
            selectionMode: widget.selectionMode,
            showSupplierColumn: widget.showSupplierColumn,
            showCostColumn: widget.showCostColumn,
            onToggleSelect: () => widget.onToggleSelect(product.id),
            onLongPressSelect: () => widget.onLongPressSelect(product.id),
          );
        },
      );
    }

    final allSelected = widget.products.isNotEmpty &&
        widget.selectedIds.length == widget.products.length;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: widget.products.length + 1, // Header + rows
        itemBuilder: (context, index) {
          if (index == 0) {
            // Table header
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                if (widget.selectionMode)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (_) => widget.onSelectAll(),
                      activeColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                const SizedBox(width: 32), // Added space for expand icon
                _th('Produk', flex: 4),
                _th('Kategori', flex: 1),
                if (widget.showSupplierColumn)
                  _th('Supplier & Ongkir', flex: 1),
                _th('Stok', flex: 1, align: TextAlign.right),
                if (widget.showCostColumn)
                  _th('Modal', flex: 1, align: TextAlign.right),
                _th('Harga Jual', flex: 1, align: TextAlign.right),
                _th('Profit', flex: 1, align: TextAlign.right),
                _th('Aksi', flex: 1, align: TextAlign.center),
              ]),
            );
          }

          final product = widget.products[index - 1];
          return RepaintBoundary(
            child: _ProductRow(
              key: ValueKey('prod_row_${product.id}'),
              product: product,
              isEven: index.isEven,
              isSelected: widget.selectedIds.contains(product.id),
              selectionMode: widget.selectionMode,
              showSupplierColumn: widget.showSupplierColumn,
              showCostColumn: widget.showCostColumn,
              onToggleSelect: () => widget.onToggleSelect(product.id),
              onLongPressSelect: () => widget.onLongPressSelect(product.id),
            ),
          );
        },
      ),
    );
  }

  Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CompactProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool selected;
  final bool selectionMode;
  final bool showSupplierColumn;
  final bool showCostColumn;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPressSelect;

  const _CompactProductCard({
    super.key,
    required this.product,
    required this.selected,
    required this.selectionMode,
    required this.showSupplierColumn,
    required this.showCostColumn,
    required this.onToggleSelect,
    required this.onLongPressSelect,
  });

  @override
  ConsumerState<_CompactProductCard> createState() =>
      _CompactProductCardState();
}

class _CompactProductCardState extends ConsumerState<_CompactProductCard> {
  bool _expanded = false;

  Future<void> _adjustStock() async {
    var enteredAdjustment = '';
    final rawAdjustment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Stok Instan'),
        content: TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
          decoration: const InputDecoration(
            labelText: 'Perubahan stok (+/-)',
            hintText: 'Contoh: 12 atau -3',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => enteredAdjustment = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, enteredAdjustment),
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
    if (rawAdjustment == null || rawAdjustment.trim().isEmpty) return;
    final adjustment = Formatters.parseQuantity(rawAdjustment);
    if (adjustment == 0) {
      if (mounted) showError(context, 'Masukkan perubahan stok bukan nol.');
      return;
    }
    try {
      await ref
          .read(productsActionProvider)
          .adjustStock(widget.product.id, adjustment);
      if (mounted) showSuccess(context, 'Stok diperbarui');
    } catch (e) {
      if (mounted) showError(context, 'Gagal memperbarui stok: $e');
    }
  }

  Future<void> _openStockAdjustment() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _adjustStock();
  }

  Future<void> _deleteProduct() async {
    final product = widget.product;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Produk',
      content:
          'Yakin hapus "${product.name}"? Data tagihan supplier dan ekspedisi terkait juga dapat terpengaruh.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(productsActionProvider).deleteProduct(product.id);
      if (mounted) showSuccess(context, 'Produk dihapus');
    } catch (e) {
      if (mounted) showError(context, 'Gagal menghapus produk: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final financials = product.financials;
    final profit = product.basePrice - product.costPrice;
    final stockColor = product.stock <= 0
        ? AppTheme.danger
        : product.isLowStock
            ? AppTheme.warning
            : AppTheme.success;

    return GestureDetector(
      onLongPress: widget.selectionMode ? null : widget.onLongPressSelect,
      onTap: widget.selectionMode ? widget.onToggleSelect : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: widget.selected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: widget.selected ? AppTheme.accent : AppTheme.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.selectionMode) ...[
                    Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onToggleSelect(),
                      activeColor: AppTheme.accent,
                    ),
                    const SizedBox(width: 4),
                  ],
                  ProductImage(imagePath: product.imagePath, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: widget.selectionMode
                          ? widget.onToggleSelect
                          : () => ProductDetailDialog.show(context, product),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            product.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          if (product.barcode?.isNotEmpty == true)
                            Text(
                              product.barcode!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Aksi produk',
                    onSelected: (action) {
                      switch (action) {
                        case 'restock':
                          RestockDialog.show(context, product);
                        case 'stock':
                          _openStockAdjustment();
                        case 'edit':
                          ProductFormDialog.show(context, product: product);
                        case 'delete':
                          _deleteProduct();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'restock',
                          child: ListTile(
                              leading: Icon(Icons.add_shopping_cart_rounded),
                              title: Text('Restock'))),
                      PopupMenuItem(
                        value: 'stock',
                        child: ListTile(
                            leading: Icon(Icons.tune_rounded),
                            title: Text('Update stok instan')),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_rounded),
                            title: Text('Ubah produk')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded,
                                color: AppTheme.danger),
                            title: Text('Hapus produk')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _CompactProductMetric(
                        label: 'STOK',
                        value:
                            '${Formatters.decimal(product.stock)} ${product.baseUnit}',
                        color: stockColor),
                  ),
                  Expanded(
                    child: _CompactProductMetric(
                        label: 'HARGA JUAL',
                        value: Formatters.currency(product.basePrice),
                        color: AppTheme.textPrimary),
                  ),
                  Expanded(
                    child: _CompactProductMetric(
                        label: 'PROFIT',
                        value: Formatters.currency(profit),
                        color:
                            profit >= 0 ? AppTheme.success : AppTheme.danger),
                  ),
                ],
              ),
            ),
            ExpansionTile(
              initiallyExpanded: _expanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _expanded = expanded),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: const Text('Detail & riwayat stok',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    if (widget.showCostColumn)
                      _CompactProductMetric(
                          label: 'HARGA MODAL',
                          value: Formatters.currency(product.costPrice)),
                    _CompactProductMetric(
                        label: 'SATUAN', value: product.baseUnit),
                    _CompactProductMetric(
                        label: 'PEMBARUAN',
                        value: Formatters.dateTime(product.updatedAt)),
                    if (widget.showSupplierColumn &&
                        financials.supplierName != null)
                      _CompactProductMetric(
                          label: 'SUPPLIER', value: financials.supplierName!),
                    if (widget.showSupplierColumn &&
                        financials.shippingServiceName != null)
                      _CompactProductMetric(
                          label: 'EKSPEDISI',
                          value: financials.shippingServiceName!),
                  ],
                ),
                const SizedBox(height: 12),
                _CompactRestockHistory(product: product),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactProductMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _CompactProductMetric(
      {required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _CompactRestockHistory extends ConsumerWidget {
  final Product product;
  const _CompactRestockHistory({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(restockHistoryProvider);
    return historyAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const Text('Riwayat restock gagal dimuat',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      data: (history) {
        final records = history
            .where((record) => record.productId == product.id)
            .take(5)
            .toList();
        if (records.isEmpty) {
          return const Text('Belum ada riwayat restock',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RIWAYAT RESTOCK',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final record in records)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '+${Formatters.decimal(record.quantityAdded)} ${record.unitName}',
                    style: const TextStyle(fontSize: 11)),
                subtitle: Text(Formatters.dateTime(record.createdAt),
                    style: const TextStyle(fontSize: 10)),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Aksi riwayat restock',
                  onSelected: (action) async {
                    if (action == 'edit') {
                      RestockDialog.show(context, product, record: record);
                      return;
                    }
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Hapus Riwayat Restock',
                      content:
                          'Stok akan dikurangi otomatis sesuai jumlah batch ini. Lanjutkan?',
                    );
                    if (confirmed) {
                      await ref
                          .read(restockNotifierProvider.notifier)
                          .deleteRestock(record);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah riwayat')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Hapus riwayat')),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProductRow extends ConsumerStatefulWidget {
  final Product product;
  final bool isEven;
  final bool isSelected;
  final bool selectionMode;
  final bool showSupplierColumn;
  final bool showCostColumn;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPressSelect;

  const _ProductRow({
    super.key,
    required this.product,
    required this.isEven,
    required this.isSelected,
    required this.selectionMode,
    required this.showSupplierColumn,
    required this.showCostColumn,
    required this.onToggleSelect,
    required this.onLongPressSelect,
  });

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  bool _expanded = false;

  Future<void> _adjustStock() async {
    var enteredValue = '';
    final rawValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Stok Instan'),
        content: TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
          decoration: const InputDecoration(
            labelText: 'Perubahan stok (+/-)',
            hintText: 'Contoh: 12 atau -3',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => enteredValue = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, enteredValue),
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
    if (rawValue == null || rawValue.trim().isEmpty) return;
    final delta = Formatters.parseQuantity(rawValue);
    if (delta == 0) {
      if (mounted) showError(context, 'Masukkan perubahan stok bukan nol.');
      return;
    }
    try {
      await ref
          .read(productsActionProvider)
          .adjustStock(widget.product.id, delta);
      if (mounted) showSuccess(context, 'Stok diperbarui');
    } catch (e) {
      if (mounted) showError(context, 'Gagal memperbarui stok: $e');
    }
  }

  Future<void> _openStockAdjustment() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _adjustStock();
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Produk',
      content:
          'Yakin hapus "${widget.product.name}"? Data terkait tidak dapat dipulihkan.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(productsActionProvider).deleteProduct(widget.product.id);
      if (mounted) showSuccess(context, 'Produk dihapus');
    } catch (e) {
      if (mounted) showError(context, 'Gagal menghapus produk: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profit = widget.product.basePrice - widget.product.costPrice;
    final f = widget.product.financials;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accent.withValues(alpha: 0.05)
                : (_expanded
                    ? AppTheme.surfaceAlt.withValues(alpha: 0.1)
                    : (widget.isEven ? AppTheme.card : AppTheme.surface)),
            border: Border(
              left: BorderSide(
                  color: widget.isSelected ? AppTheme.accent : AppTheme.border),
              right: BorderSide(
                  color: widget.isSelected ? AppTheme.accent : AppTheme.border),
              bottom: BorderSide(color: AppTheme.border),
            ),
          ),
          child: GestureDetector(
            onLongPress: widget.selectionMode ? null : widget.onLongPressSelect,
            child: Row(children: [
              if (widget.selectionMode)
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggleSelect(),
                    activeColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),

              // Expand Toggle
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 20,
                    color: AppTheme.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),

              // Product name + icon
              Expanded(
                  flex: 4,
                  child: InkWell(
                    onTap: () =>
                        ProductDetailDialog.show(context, widget.product),
                    child: Row(children: [
                      ProductImage(
                          imagePath: widget.product.imagePath, size: 36),
                      const SizedBox(width: 12),
                      Flexible(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(widget.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            Row(
                              children: [
                                Text(widget.product.baseUnit,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary)),
                                if (widget.product.barcode != null) ...[
                                  const SizedBox(width: 8),
                                  Text('• ${widget.product.barcode}',
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          color: AppTheme.textMuted)),
                                ],
                              ],
                            ),
                          ])),
                    ]),
                  )),
              Expanded(
                  flex: 1,
                  child: Text(widget.product.category,
                      style: const TextStyle(fontSize: 12))),

              // Supplier & Shipping Info
              if (widget.showSupplierColumn)
                Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (f.supplierName != null)
                          _statusBadge(Icons.business_rounded, f.supplierName!,
                              f.supplierPaymentStatus),
                        if (f.shippingServiceName != null)
                          _statusBadge(Icons.local_shipping_rounded,
                              f.shippingServiceName!, f.shippingPaymentStatus),
                        if (f.supplierName == null &&
                            f.shippingServiceName == null)
                          const Text('—',
                              style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    )),

              Expanded(
                  flex: 1,
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (widget.product.isLowStock)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.warning_amber_rounded,
                            color: AppTheme.warning, size: 14),
                      ),
                    Text(
                      Formatters.decimal(widget.product.stock),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: widget.product.isLowStock
                            ? AppTheme.warning
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ])),
              if (widget.showCostColumn)
                Expanded(
                    flex: 1,
                    child: Text(Formatters.currency(widget.product.costPrice),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary))),
              Expanded(
                  flex: 1,
                  child: Text(Formatters.currency(widget.product.basePrice),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(
                  flex: 1,
                  child: Text(Formatters.currency(profit),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color:
                              profit >= 0 ? AppTheme.success : AppTheme.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 12))),

              Expanded(
                flex: 1,
                child: Center(
                  child: PopupMenuButton<String>(
                    tooltip: 'Aksi produk',
                    onSelected: (action) {
                      switch (action) {
                        case 'restock':
                          RestockDialog.show(context, widget.product);
                        case 'stock':
                          _openStockAdjustment();
                        case 'edit':
                          ProductFormDialog.show(context,
                              product: widget.product);
                        case 'delete':
                          _deleteProduct();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'restock',
                        child: ListTile(
                          leading: Icon(Icons.add_shopping_cart_rounded),
                          title: Text('Restock'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'stock',
                        child: ListTile(
                          leading: Icon(Icons.tune_rounded),
                          title: Text('Update stok instan'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Ubah produk'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: AppTheme.danger),
                          title: Text('Hapus produk'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (_expanded) _buildInventoryHub(widget.product),
      ],
    );
  }

  Widget _buildInventoryHub(Product p) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('RIWAYAT RESTOCK PRODUK',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accent,
                        letterSpacing: 1.1)),
              ],
            ),
          ),

          _buildHistoryList(p),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHistoryList(Product p) {
    final historyAsync = ref.watch(restockHistoryProvider);

    return historyAsync.when(
      data: (list) {
        final prodRecords = list.where((r) => r.productId == p.id).toList();
        if (prodRecords.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(56, 8, 16, 16),
            child: Text('Belum ada riwayat pengadaan untuk produk ini.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic)),
          );
        }

        return Column(
          children: prodRecords
              .map((r) => _RestockHistoryRow(record: r, product: p))
              .toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(56, 16, 16, 16),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(56, 8, 16, 16),
        child: Text('Gagal memuat riwayat'),
      ),
    );
  }

  Widget _statusBadge(IconData icon, String label, PaymentStatus status) {
    if (status == PaymentStatus.notApplicable) return const SizedBox();

    final color =
        status == PaymentStatus.paid ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockHistoryRow extends ConsumerWidget {
  final RestockRecord record;
  final Product product;
  const _RestockHistoryRow({required this.record, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Expanded(
            flex: 2,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Formatters.dateTime(record.createdAt),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              if (record.notes != null)
                Text(record.notes!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(
            flex: 2,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '+${Formatters.decimal(record.quantityAdded)} ${record.unitName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                      fontSize: 13)),
              Text('Modal: ${Formatters.currency(record.totalCostPerUnit)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            flex: 3,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (record.supplierName != null)
                _miniBadge(Icons.business_rounded, record.supplierName!,
                    record.supplierPaymentStatus),
              if (record.shippingServiceName != null)
                _miniBadge(Icons.local_shipping_rounded,
                    record.shippingServiceName!, record.shippingPaymentStatus),
            ]),
          ),
          const SizedBox(width: 16),
          // Actions
          IconButton(
            onPressed: () =>
                RestockDialog.show(context, product, record: record),
            icon: const Icon(Icons.edit_rounded,
                size: 16, color: AppTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit Riwayat',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: 'Hapus Riwayat Restock',
                  content:
                      'Yakin hapus data ini? Stok akan dikurangi otomatis sesuai jumlah batch ini.');
              if (ok) {
                await ref
                    .read(restockNotifierProvider.notifier)
                    .deleteRestock(record);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: AppTheme.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Hapus Riwayat',
          ),
        ]),
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label, PaymentStatus status) {
    final color =
        status == PaymentStatus.paid ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 9, color: color, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;
  const _FilterLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted));
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.accent : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}
