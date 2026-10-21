import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/utils/image_helper.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_financials.dart';
import '../providers/barcode_history_provider.dart';
import '../../inventory/providers/bill_payment_provider.dart';

final _uuid = Uuid();

// ── Repository ────────────────────────────────────────────────────────────

class ProductRepository {
  final String _uid;
  final SupabaseClient _client;
  final BarcodeHistoryRepository _historyRepo;
  final Ref _ref;

  ProductRepository(this._uid, this._client, this._historyRepo, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'products');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final box = await _getBox();
    if (box.isNotEmpty && !force) return;

    final response = await _client
        .from('products')
        .select()
        .eq('user_id', _uid)
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> allEntries = {};
    for (final item in response) {
      allEntries[item['id']] = LocalDatabase.sanitize(item);
    }

    if (force) await box.clear();

    const int chunkSize = 50;
    final keys = allEntries.keys.toList();

    for (var i = 0; i < keys.length; i += chunkSize) {
      final end = (i + chunkSize < keys.length) ? i + chunkSize : keys.length;
      final Map<String, dynamic> batch = {};

      for (var j = i; j < end; j++) {
        final key = keys[j];
        batch[key] = allEntries[key];
      }

      if (batch.isNotEmpty) {
        await box.putAll(batch);
      }
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  // ── Read Operations ────────────────────────────────────────────────────────

  Stream<List<Product>> getProductsStream() async* {
    final box = await _getBox();
    yield _productsFromBox(box);
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
    final finalProduct = product.copyWith(
      units: units,
      updatedAt: DateTime.now(),
    );
    final data = finalProduct.toMap();

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

    final f = product.financials;
    if (f.supplierPaidAmount > 0) {
      await _ref.read(billPaymentRepositoryProvider).createInitialPayment(
          billId: product.id,
          amount: f.supplierPaidAmount,
          isForSupplier: true);
    }
    if (f.shippingPaidAmount > 0) {
      await _ref.read(billPaymentRepositoryProvider).createInitialPayment(
          billId: product.id,
          amount: f.shippingPaidAmount,
          isForSupplier: false);
    }
  }

  Future<void> saveProductsBatch(
      List<Map<Product, List<ProductUnit>>> productsWithUnits) async {
    final box = await _getBox();
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
    for (final item in productsWithUnits) {
      final p = item.keys.first;
      final nameLower = p.name.trim().toLowerCase();
      final barcode = p.barcode?.trim();

      if (nameLower.isEmpty) continue;

      if (barcode != null && barcode.isNotEmpty) {
        if (barcodeToProduct.containsKey(barcode)) {
          final existingProduct = barcodeToProduct[barcode]!;
          toProcess.add(p.copyWith(
            id: existingProduct.id,
            createdAt: existingProduct.createdAt,
            updatedAt: DateTime.now(),
          ));
          continue;
        }
      }

      if (nameToProduct.containsKey(nameLower)) continue;
      toProcess.add(p);
    }

    if (toProcess.isEmpty) return;

    final tasks = <SyncTask>[];
    final barcodeLogItems = <({String barcode, String name, String id})>[];

    for (final p in toProcess) {
      final data = p.toMap();
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
      final path = 'users/$_uid/products/$productId.jpg';
      await _client.storage.from('products').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return _client.storage.from('products').getPublicUrl(path);
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

    if (p.barcode != null) {
      await _historyRepo.archiveBarcode(p.barcode!);
    }

    await box.delete(id);
    await _deleteLocalProductImage(p.imagePath);

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
        await _deleteLocalProductImage(p.imagePath);
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

  Future<void> wipeAllProducts() async {
    final box = await _getBox();
    final allProducts = await getAllProducts();
    final ids = allProducts.map((p) => p.id).toList();

    for (final p in allProducts) {
      if (p.barcode != null) await _historyRepo.archiveBarcode(p.barcode!);
      await _deleteLocalProductImage(p.imagePath);
    }

    await box.clear();

    final tasks = ids
        .map((id) => SyncTask(
              id: _uuid.v4(),
              collection: 'products',
              documentId: id,
              action: SyncAction.delete,
              data: {},
              createdAt: DateTime.now(),
            ))
        .toList();

    if (tasks.isNotEmpty) {
      await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
    }
  }

  Future<void> updateStock(String productId, double delta) async {
    final box = await _getBox();
    final data = box.get(productId);
    if (data == null) return;

    final p = Product.fromMap(Map<String, dynamic>.from(data as Map));
    final updated = p.copyWith(stock: p.stock + delta);

    await box.put(productId, updated.toMap());

    await _ref.read(syncProvider.notifier).addToQueue(
          collection: 'products',
          documentId: productId,
          action: SyncAction.update,
          data: updated.toMap(),
        );
  }

  Future<void> dismissInitialBill(Product p, {required bool isSupplier}) async {
    final box = await _getBox();
    final updated = p.copyWith(
      financials: p.financials.copyWith(
        supplierPaymentStatus: isSupplier
            ? PaymentStatus.notApplicable
            : p.financials.supplierPaymentStatus,
        shippingPaymentStatus: !isSupplier
            ? PaymentStatus.notApplicable
            : p.financials.shippingPaymentStatus,
      ),
    );
    await box.put(p.id, updated.toMap());

    await _ref.read(syncProvider.notifier).addToQueue(
          collection: 'products',
          documentId: p.id,
          action: SyncAction.update,
          data: updated.toMap(),
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

  Future<void> _deleteLocalProductImage(String? storedPath) async {
    final localPath = await ImageHelper.resolveLocalPath(storedPath);
    await ImageHelper.deleteLocal(localPath);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

// ... (Rest of the file remains similar but uses Supabase where appropriate)

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final client = ref.read(supabaseClientProvider);
  final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
  return ProductRepository(user?.uid ?? 'unknown', client, historyRepo, ref);
});

enum ProductSortField {
  name,
  category,
  stock,
  cost,
  price,
  profit,
  created,
  updated
}

class ProductSort {
  final ProductSortField field;
  final bool ascending;
  const ProductSort(
      {this.field = ProductSortField.name, this.ascending = true});

  ProductSort copyWith({ProductSortField? field, bool? ascending}) =>
      ProductSort(
          field: field ?? this.field, ascending: ascending ?? this.ascending);
}

class ProductSortNotifier extends Notifier<ProductSort> {
  @override
  ProductSort build() => const ProductSort();
  void setField(ProductSortField field) => state = state.copyWith(field: field);
  void toggleOrder() => state = state.copyWith(ascending: !state.ascending);
}

class ProductFilters {
  final String stock; // all, in, low, out
  final String supplier; // all, paid, unpaid
  final String shipping; // all, paid, unpaid
  const ProductFilters(
      {this.stock = 'all', this.supplier = 'all', this.shipping = 'all'});

  ProductFilters copyWith(
          {String? stock, String? supplier, String? shipping}) =>
      ProductFilters(
          stock: stock ?? this.stock,
          supplier: supplier ?? this.supplier,
          shipping: shipping ?? this.shipping);
}

class ProductFiltersNotifier extends Notifier<ProductFilters> {
  @override
  ProductFilters build() => const ProductFilters();
  void setStock(String v) => state = state.copyWith(stock: v);
  void setSupplier(String v) => state = state.copyWith(supplier: v);
  void setShipping(String v) => state = state.copyWith(shipping: v);
}

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
    _debounceTimer =
        Timer(const Duration(milliseconds: 300), () => state = query);
  }
}

class ProductCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? category) => state = category;
}

final productSearchQueryProvider =
    NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);
final productCategoryFilterProvider =
    NotifierProvider<ProductCategoryFilter, String?>(ProductCategoryFilter.new);
final productSortProvider =
    NotifierProvider<ProductSortNotifier, ProductSort>(ProductSortNotifier.new);
final productFiltersProvider =
    NotifierProvider<ProductFiltersNotifier, ProductFilters>(
        ProductFiltersNotifier.new);

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final query = ref.watch(productSearchQueryProvider).toLowerCase().trim();
  final category = ref.watch(productCategoryFilterProvider);
  final filters = ref.watch(productFiltersProvider);

  return productsAsync.when(
    data: (products) {
      return products.where((p) {
        bool matchSearch = true;
        if (query.isNotEmpty) {
          final nameMatch = p.name.toLowerCase().contains(query);
          final barcodeMatch =
              p.barcode?.toLowerCase().contains(query) ?? false;
          final catMatch = p.category.toLowerCase().contains(query);
          matchSearch = nameMatch || barcodeMatch || catMatch;
        }
        if (!matchSearch) return false;
        if (category != null && p.category != category) return false;
        if (filters.stock == 'in' && p.stock <= 10) return false;
        if (filters.stock == 'low' && (!p.isLowStock || p.stock <= 0)) {
          return false;
        }
        if (filters.stock == 'out' && p.stock > 0) return false;
        if (filters.supplier == 'paid' &&
            p.financials.supplierPaymentStatus != PaymentStatus.paid) {
          return false;
        }
        if (filters.supplier == 'unpaid' &&
            p.financials.supplierPaymentStatus != PaymentStatus.unpaid) {
          return false;
        }
        if (filters.shipping == 'paid' &&
            p.financials.shippingPaymentStatus != PaymentStatus.paid) {
          return false;
        }
        if (filters.shipping == 'unpaid' &&
            p.financials.shippingPaymentStatus != PaymentStatus.unpaid) {
          return false;
        }
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
      case ProductSortField.category:
        cmp = a.category.compareTo(b.category);
        break;
      case ProductSortField.stock:
        cmp = a.stock.compareTo(b.stock);
        break;
      case ProductSortField.cost:
        cmp = a.costPrice.compareTo(b.costPrice);
        break;
      case ProductSortField.price:
        cmp = a.basePrice.compareTo(b.basePrice);
        break;
      case ProductSortField.profit:
        cmp = (a.basePrice - a.costPrice).compareTo(b.basePrice - b.costPrice);
        break;
      case ProductSortField.created:
        cmp = a.createdAt.compareTo(b.createdAt);
        break;
      case ProductSortField.updated:
        cmp = a.updatedAt.compareTo(b.updatedAt);
        break;
      default:
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    return sort.ascending ? cmp : -cmp;
  });
  return list;
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

  Future<void> wipeAllProducts() async {
    await _repo.wipeAllProducts();
  }
}

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
