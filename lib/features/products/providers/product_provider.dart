import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_financials.dart';
import '../providers/barcode_history_provider.dart';

final _uuid = Uuid();

// ── Repository ────────────────────────────────────────────────────────────

class ProductRepository {
  final String _uid;
  final sb.SupabaseClient _supabase;
  final BarcodeHistoryRepository _historyRepo;
  final Ref _ref;

  ProductRepository(this._uid, this._supabase, this._historyRepo, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'products');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final box = await _getBox();
    if (box.isNotEmpty && !force) return; // Already cached

    final response = await _supabase.from('products').select().eq('user_id', _uid);
    if (force) await box.clear();

    for (final data in response) {
      await box.put(data['id'], LocalDatabase.sanitize(data));
    }
  }

  // ── Read Operations ────────────────────────────────────────────────────────

  Stream<List<Product>> getProductsStream() async* {
    final box = await _getBox();
    
    // Initial fetch from Hive
    yield _productsFromBox(box);

    // Watch for Hive changes
    yield* box.watch().map((_) => _productsFromBox(box));
  }

  Future<List<Product>> getAllProducts() async {
    final box = await _getBox();
    return _productsFromBox(box);
  }

  List<Product> _productsFromBox(Box box) {
    final list = box.values.map((data) {
      return Product.fromMap(Map<String, dynamic>.from(data as Map));
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ── Write Operations ───────────────────────────────────────────────────────

  Future<void> saveProduct(Product product, List<ProductUnit> units) async {
    final box = await _getBox();
    
    // Create the final product object with units attached
    final finalProduct = product.copyWith(units: units);
    final data = finalProduct.toMap();
    data['user_id'] = _uid; // Ensure user_id is set for Supabase

    await box.put(product.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: product.id,
      action: SyncAction.update,
      data: data,
    );

    if (product.barcode != null && product.barcode!.isNotEmpty) {
      await _historyRepo.logBarcode(product.barcode!, product.name, product.id);
    }
  }

  Future<void> saveProductsBatch(
      List<Map<Product, List<ProductUnit>>> productsWithUnits) async {
    final box = await _getBox();
    
    // 1. Fetch current local data for mapping and validation
    final existing = await getAllProducts();
    final Map<String, Product> barcodeToProduct = {};
    final Map<String, Product> nameToProduct = {};
    
    for (final p in existing) {
      if (p.barcode != null && p.barcode!.isNotEmpty) {
        barcodeToProduct[p.barcode!.trim()] = p;
      }
      nameToProduct[p.name.trim().toLowerCase()] = p;
    }

    final toProcess = <Product>[];
    final seenBarcodesInBatch = <String>{};
    final seenNamesInBatch = <String>{};

    for (final item in productsWithUnits) {
      final p = item.keys.first;
      final nameLower = p.name.trim().toLowerCase();
      final barcode = p.barcode?.trim();

      // Check for Barcode match first (PRIORITY: UPDATE)
      if (barcode != null && barcode.isNotEmpty) {
        if (barcodeToProduct.containsKey(barcode)) {
          // UPDATE case: Use existing ID but update everything else
          final existingProduct = barcodeToProduct[barcode]!;
          toProcess.add(p.copyWith(
            id: existingProduct.id, 
            createdAt: existingProduct.createdAt,
            updatedAt: DateTime.now(),
          ));
          continue;
        }
        
        if (seenBarcodesInBatch.contains(barcode)) continue;
        seenBarcodesInBatch.add(barcode);
      }

      // Check for Name duplicate if not a barcode match (SKIP if already exists with different barcode)
      if (nameToProduct.containsKey(nameLower) || seenNamesInBatch.contains(nameLower)) {
        continue;
      }

      seenNamesInBatch.add(nameLower);
      toProcess.add(p);
    }

    if (toProcess.isEmpty) return;

    // 3. Process items in Hive and Queue
    final tasks = <SyncTask>[];
    final barcodeLogItems = <({String barcode, String name, String id})>[];

    for (final p in toProcess) {
      final data = p.toMap();
      data['user_id'] = _uid;
      // We assume units are handled elsewhere or empty for simple import
      data['units'] = p.units.map((u) => u.toMap()).toList();

      await box.put(p.id, data);
      
      tasks.add(SyncTask(
        id: _uuid.v4(),
        collection: 'products',
        documentId: p.id,
        action: SyncAction.update,
        data: data,
        createdAt: DateTime.now(),
      ));

      if (p.barcode != null && p.barcode!.isNotEmpty) {
        barcodeLogItems.add((barcode: p.barcode!, name: p.name, id: p.id));
      }
    }

    if (tasks.isNotEmpty) {
      await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
    }

    if (barcodeLogItems.isNotEmpty) {
      await _historyRepo.logBarcodesBatch(barcodeLogItems);
    }
  }

  Future<void> updateProductsWithBarcodesBatch(List<Product> products) async {
    final box = await _getBox();
    final tasks = <SyncTask>[];

    for (final p in products) {
      final data = p.toMap();
      data['user_id'] = _uid;
      data['units'] = p.units.map((u) => u.toMap()).toList();
      
      await box.put(p.id, data);
      
      tasks.add(SyncTask(
        id: _uuid.v4(),
        collection: 'products',
        documentId: p.id,
        action: SyncAction.update,
        data: data,
        createdAt: DateTime.now(),
      ));
    }

    await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
  }

  Future<String?> uploadProductImage(String productId, Uint8List bytes) async {
    try {
      final path = 'products/$productId.jpg';
      await _supabase.storage.from('users').uploadBinary(
        '$_uid/$path',
        bytes,
        fileOptions: const sb.FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return _supabase.storage.from('users').getPublicUrl('$_uid/$path');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> deleteProduct(String id) async {
    final box = await _getBox();
    final productData = box.get(id);
    if (productData == null) return;
    
    final p = Product.fromMap(Map<String, dynamic>.from(productData as Map));

    // Archive barcode in history if exists
    if (p.barcode != null) {
      await _historyRepo.archiveBarcode(p.barcode!);
    }

    // 1. Local delete
    await box.delete(id);

    // 2. Queue Sync delete
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: id,
      action: SyncAction.delete,
      data: {},
    );
  }

  Future<void> deleteProductsBatch(List<String> ids) async {
    final box = await _getBox();
    final tasks = <SyncTask>[];

    for (final id in ids) {
      final data = box.get(id);
      if (data != null) {
        final p = Product.fromMap(Map<String, dynamic>.from(data as Map));
        if (p.barcode != null) await _historyRepo.archiveBarcode(p.barcode!);
      }
      
      await box.delete(id);
      tasks.add(SyncTask(
        id: _uuid.v4(),
        collection: 'products',
        documentId: id,
        action: SyncAction.delete,
        data: {},
        createdAt: DateTime.now(),
      ));
    }

    await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
  }

  Future<void> updateStock(String productId, double delta) async {
    final box = await _getBox();
    final data = box.get(productId);
    if (data == null) return;

    final p = Product.fromMap(Map<String, dynamic>.from(data as Map));
    final updated = p.copyWith(stock: p.stock + delta);
    final finalData = updated.toMap();
    finalData['user_id'] = _uid;

    await box.put(productId, finalData);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: productId,
      action: SyncAction.update,
      data: finalData,
    );
  }

  Future<void> dismissInitialBill(Product p, {required bool isSupplier}) async {
    final box = await _getBox();
    final updated = p.copyWith(
      financials: p.financials.copyWith(
        supplierPaymentStatus: isSupplier ? PaymentStatus.notApplicable : p.financials.supplierPaymentStatus,
        shippingPaymentStatus: !isSupplier ? PaymentStatus.notApplicable : p.financials.shippingPaymentStatus,
      ),
    );
    final data = updated.toMap();
    data['user_id'] = _uid;

    await box.put(p.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: p.id,
      action:     SyncAction.update,
      data:       data,
    );
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final box = await _getBox();
    final normalized = barcode.trim();
    final data = box.values.firstWhereOrNull((d) {
      final m = Map<String, dynamic>.from(d as Map);
      return m['barcode'] == normalized;
    });
    if (data == null) return null;
    return Product.fromMap(Map<String, dynamic>.from(data as Map));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

class ProductSearchQuery extends Notifier<String> {
  Timer? _debounceTimer;

  @override
  String build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return '';
  }

  void set(String query) {
    if (query.isEmpty) {
      _debounceTimer?.cancel();
      state = '';
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      state = query;
    });
  }
}

final productSearchQueryProvider = NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);

class ProductCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? category) => state = category;
}

final productCategoryFilterProvider = NotifierProvider<ProductCategoryFilter, String?>(ProductCategoryFilter.new);

enum ProductSortField { name, category, stock, cost, price, profit, created, updated }

class ProductSort {
  final ProductSortField field;
  final bool ascending;
  const ProductSort({this.field = ProductSortField.name, this.ascending = true});

  ProductSort copyWith({ProductSortField? field, bool? ascending}) =>
      ProductSort(field: field ?? this.field, ascending: ascending ?? this.ascending);
}

class ProductSortNotifier extends Notifier<ProductSort> {
  @override
  ProductSort build() => const ProductSort();
  void setField(ProductSortField field) => state = state.copyWith(field: field);
  void toggleOrder() => state = state.copyWith(ascending: !state.ascending);
}

final productSortProvider = NotifierProvider<ProductSortNotifier, ProductSort>(ProductSortNotifier.new);

// Filters for Product Management
class ProductFilters {
  final String stock; // all, in, low, out
  final String supplier; // all, paid, unpaid
  final String shipping; // all, paid, unpaid
  const ProductFilters({this.stock = 'all', this.supplier = 'all', this.shipping = 'all'});

  ProductFilters copyWith({String? stock, String? supplier, String? shipping}) =>
      ProductFilters(stock: stock ?? this.stock, supplier: supplier ?? this.supplier, shipping: shipping ?? this.shipping);
}

class ProductFiltersNotifier extends Notifier<ProductFilters> {
  @override
  ProductFilters build() => const ProductFilters();
  void setStock(String v) => state = state.copyWith(stock: v);
  void setSupplier(String v) => state = state.copyWith(supplier: v);
  void setShipping(String v) => state = state.copyWith(shipping: v);
}

final productFiltersProvider = NotifierProvider<ProductFiltersNotifier, ProductFilters>(ProductFiltersNotifier.new);

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final query = ref.watch(productSearchQueryProvider).toLowerCase().trim();
  final category = ref.watch(productCategoryFilterProvider);
  final filters = ref.watch(productFiltersProvider);

  return productsAsync.when(
    data: (products) {
      return products.where((p) {
        // 1. Search Match
        bool matchSearch = true;
        if (query.isNotEmpty) {
          final nameMatch = p.name.toLowerCase().contains(query);
          final barcodeMatch = p.barcode?.toLowerCase().contains(query) ?? false;
          final catMatch = p.category.toLowerCase().contains(query);
          matchSearch = nameMatch || barcodeMatch || catMatch;
        }
        if (!matchSearch) return false;

        // 2. Category Match
        if (category != null && p.category != category) return false;

        // 3. Stock Match
        if (filters.stock == 'in' && p.stock <= 10) return false;
        if (filters.stock == 'low' && (!p.isLowStock || p.stock <= 0)) return false;
        if (filters.stock == 'out' && p.stock > 0) return false;

        // 4. Supplier Match
        if (filters.supplier == 'paid' && p.financials.supplierPaymentStatus != PaymentStatus.paid) return false;
        if (filters.supplier == 'unpaid' && p.financials.supplierPaymentStatus != PaymentStatus.unpaid) return false;

        // 5. Shipping Match
        if (filters.shipping == 'paid' && p.financials.shippingPaymentStatus != PaymentStatus.paid) return false;
        if (filters.shipping == 'unpaid' && p.financials.shippingPaymentStatus != PaymentStatus.unpaid) return false;

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final sortedProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(filteredProductsProvider);
  final sort = ref.watch(productSortProvider);

  final list = [...products];
  list.sort((a, b) {
    int cmp;
    switch (sort.field) {
      case ProductSortField.category: cmp = a.category.compareTo(b.category); break;
      case ProductSortField.stock:    cmp = a.stock.compareTo(b.stock); break;
      case ProductSortField.cost:     cmp = a.costPrice.compareTo(b.costPrice); break;
      case ProductSortField.price:    cmp = a.basePrice.compareTo(b.basePrice); break;
      case ProductSortField.profit:   cmp = (a.basePrice - a.costPrice).compareTo(b.basePrice - b.costPrice); break;
      case ProductSortField.created:  cmp = a.createdAt.compareTo(b.createdAt); break;
      case ProductSortField.updated:  cmp = a.updatedAt.compareTo(b.updatedAt); break;
      default:                        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    return sort.ascending ? cmp : -cmp;
  });
  return list;
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final sbClient = ref.watch(supabaseClientProvider);
  final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
  return ProductRepository(user?.uid ?? 'unknown', sbClient, historyRepo, ref);
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getProductsStream();
});

final productsActionProvider = Provider((ref) => ProductsActionNotifier(ref));

class ProductsActionNotifier {
  final Ref _ref;
  ProductsActionNotifier(this._ref);

  ProductRepository get _repo => _ref.read(productRepositoryProvider);

  Future<void> saveProduct(Product product, List<ProductUnit> units) async {
    await _repo.saveProduct(product, units);
  }

  Future<String?> uploadImage(String productId, Uint8List bytes) async {
    return await _repo.uploadProductImage(productId, bytes);
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
  }

  Future<void> deleteProductsBatch(List<String> ids) async {
    await _repo.deleteProductsBatch(ids);
  }

  Future<void> updateProductsBatch(List<Product> products) async {
    await _repo.updateProductsWithBarcodesBatch(products);
  }

  Future<void> importProducts(
      List<Map<Product, List<ProductUnit>>> products) async {
    await _repo.saveProductsBatch(products);
  }

  Future<void> adjustStock(String productId, double delta) async {
    await _repo.updateStock(productId, delta);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

Product blankProduct() => Product(
      id: _uuid.v4(),
      name: '',
      category: '',
      costPrice: 0,
      basePrice: 0,
      baseUnit: 'pcs',
      stock: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

ProductUnit blankUnit(String productId) => ProductUnit(
      id: _uuid.v4(),
      productId: productId,
      unitName: '',
      conversionRate: 1,
      sellPrice: 0,
    );
