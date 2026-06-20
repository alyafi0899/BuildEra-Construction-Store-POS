import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore
    hide Transaction;
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import '../../../core/utils/image_helper.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';

import '../providers/barcode_history_provider.dart';

final _uuid = Uuid();

// ── Repository ────────────────────────────────────────────────────────────

class ProductRepository {
  final String _uid;
  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final storage.FirebaseStorage _storage = storage.FirebaseStorage.instance;
  final BarcodeHistoryRepository _historyRepo;
  final Ref _ref;

  ProductRepository(this._uid, this._historyRepo, this._ref);

  firestore.CollectionReference get _productsCol => 
      _db.collection('users').doc(_uid).collection('products');

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'products');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    final box = await _getBox();
    if (box.isNotEmpty) return; // Already cached

    final snapshot = await _productsCol.get();
    for (final doc in snapshot.docs) {
      await box.put(doc.id, doc.data());
    }
  }

  // ── Read Operations ────────────────────────────────────────────────────────

  Stream<List<Product>> getProductsStream() async* {
    final box = await _getBox();
    
    // 1. Emit current local data immediately
    yield _productsFromBox(box);

    // 2. Listen to local changes
    yield* box.watch().map((_) => _productsFromBox(box));
  }

  List<Product> _productsFromBox(Box box) {
    final list = box.values.map((data) {
      final m = Map<String, dynamic>.from(data as Map);
      final unitsData = m['units'] as List? ?? [];
      final units = unitsData
          .map((u) => ProductUnit.fromMap(Map<String, dynamic>.from(u as Map)))
          .toList();
      return Product.fromMap(m, units: units);
    }).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<Product>> getAllProducts() async {
    final box = await _getBox();
    return _productsFromBox(box);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final products = await getAllProducts();
    final normalized = barcode.trim();
    try {
      return products.firstWhere((p) => p.barcode?.trim() == normalized);
    } catch (_) {
      return null;
    }
  }

  // ── Write Operations ───────────────────────────────────────────────────────

  Future<void> saveProduct(Product p, List<ProductUnit> units) async {
    // 1. Local Validation
    final products = await getAllProducts();
    final nameLower = p.name.trim().toLowerCase();
    
    // Check for duplicate Name
    final dupName = products.any((item) => item.name.trim().toLowerCase() == nameLower && item.id != p.id);
    if (dupName) throw 'Produk dengan nama "${p.name}" sudah ada.';

    // Check for duplicate Barcode
    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      final normalizedBarcode = p.barcode!.trim();
      final isUsed = await _historyRepo.isBarcodeUsed(normalizedBarcode);
      if (isUsed) {
        final existing = products.any((item) => item.barcode?.trim() == normalizedBarcode && item.id != p.id);
        if (existing) throw 'Barcode "${p.barcode}" sudah digunakan oleh produk lain.';
      }
    }

    final data = p.toMap();
    data['units'] = units.map((u) => u.toMap()).toList();

    // 2. Write Local
    final box = await _getBox();
    await box.put(p.id, data);

    // 3. Queue Sync
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: p.id,
      action:     SyncAction.update, // set handles both create and update
      data:       data,
    );

    // 4. Log barcode local history (simplified for now)
    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      await _historyRepo.logBarcode(p.barcode!, p.name, p.id);
    }
  }

  Future<void> updateStock(String productId, double delta) async {
    final box = await _getBox();
    final data = box.get(productId);
    if (data == null) return;

    final m = Map<String, dynamic>.from(data as Map);
    final currentStock = (m['stock'] as num? ?? 0).toDouble();
    m['stock'] = currentStock + delta;
    m['updated_at'] = DateTime.now().toIso8601String();

    await box.put(productId, m);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: productId,
      action:     SyncAction.update,
      data:       {'stock': firestore.FieldValue.increment(delta), 'updated_at': m['updated_at']},
    );
  }

  Future<void> deleteProduct(String id) async {
    final box = await _getBox();
    final data = box.get(id);
    final barcode = data != null ? (data as Map)['barcode'] as String? : null;

    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'products',
      documentId: id,
      action:     SyncAction.delete,
      data:       {},
    );

    if (barcode != null && barcode.isNotEmpty) {
      await _historyRepo.archiveBarcode(barcode);
    }

    try {
      await _storage.ref().child('users/$_uid/products/$id.jpg').delete();
    } catch (_) {}
  }

  // ── Images (Keep Online-Required for now as images are large) ────────────────

  Future<void> deleteProductsBatch(List<String> ids) async {
    final box = await _getBox();
    final tasks = <SyncTask>[];
    
    for (final id in ids) {
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
    for (final p in toProcess) {
      final data = p.toMap();
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
        await _historyRepo.logBarcode(p.barcode!, p.name, p.id);
      }
    }

    await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
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
      final compressedBytes = await ImageHelper.processImage(bytes);
      final ref = _storage.ref().child('users/$_uid/products/$productId.jpg');
      await ref.putData(
          compressedBytes, storage.SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
  return ProductRepository(user?.uid ?? 'unknown', historyRepo, ref);
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
