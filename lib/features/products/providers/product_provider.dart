import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore
    hide Transaction;
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'dart:typed_data';
import '../../../core/utils/image_helper.dart';
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

  ProductRepository(this._uid, this._historyRepo);

  firestore.CollectionReference get _productsCol => 
      _db.collection('users').doc(_uid).collection('products');

  Stream<List<Product>> getProductsStream() {
    return _productsCol
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final unitsData = data['units'] as List? ?? [];
        final units = unitsData
            .whereType<Map<String, dynamic>>()
            .map((u) => ProductUnit.fromMap(u))
            .toList();
        return Product.fromMap(data, units: units);
      }).toList();
    });
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await _productsCol.orderBy('name').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final unitsData = data['units'] as List? ?? [];
        final units = unitsData
            .whereType<Map<String, dynamic>>()
            .map((u) => ProductUnit.fromMap(u))
            .toList();
        return Product.fromMap(data, units: units);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;

    final snapshot = await _productsCol
        .where('barcode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    final unitsData = data['units'] as List? ?? [];
    final units = unitsData
        .whereType<Map<String, dynamic>>()
        .map((u) => ProductUnit.fromMap(u))
        .toList();
    return Product.fromMap(data, units: units);
  }

  Future<String?> uploadProductImage(String productId, Uint8List bytes) async {
    try {
      final compressedBytes = await ImageHelper.compressImage(bytes);
      // Path includes UID for isolation
      final ref = _storage.ref().child('users/$_uid/products/$productId.jpg');
      await ref.putData(
          compressedBytes, storage.SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProduct(Product p, List<ProductUnit> units) async {
    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      final isUsed = await _historyRepo.isBarcodeUsed(p.barcode!);

      if (isUsed) {
        final existing = await _productsCol
            .where('barcode', isEqualTo: p.barcode!.trim())
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty && existing.docs.first.id != p.id) {
          throw 'Barcode "${p.barcode}" sudah digunakan oleh produk lain.';
        }

        final historyDoc = await _db
            .collection('users')
            .doc(_uid)
            .collection('barcode_history')
            .doc(p.barcode!.trim())
            .get();
        if (historyDoc.exists && historyDoc.data()?['productId'] != p.id) {
          throw 'Barcode "${p.barcode}" pernah digunakan sebelumnya (diarsipkan).';
        }
      }
    }

    final dupName = await _productsCol
        .where('name', isEqualTo: p.name.trim())
        .limit(1)
        .get();
    if (dupName.docs.isNotEmpty && dupName.docs.first.id != p.id) {
      throw 'Produk dengan nama "${p.name}" sudah ada';
    }

    final data = p.toMap();
    data['units'] = units.map((u) => u.toMap()).toList();
    await _productsCol.doc(p.id).set(data);

    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      await _historyRepo.logBarcode(p.barcode!, p.name, p.id);
    }
  }

  Future<void> saveProductsBatch(
      List<Map<Product, List<ProductUnit>>> productsWithUnits) async {
    final existing = await getAllProducts();
    final existingBarcodes =
        existing.map((e) => e.barcode?.trim()).whereType<String>().toSet();
    final existingNames =
        existing.map((e) => e.name.trim().toLowerCase()).toSet();

    final toImport = <Map<Product, List<ProductUnit>>>[];
    final seenBarcodesInBatch = <String>{};
    final seenNamesInBatch = <String>{};

    for (final item in productsWithUnits) {
      final p = item.keys.first;
      final nameLower = p.name.trim().toLowerCase();
      final barcode = p.barcode?.trim();

      if (existingNames.contains(nameLower) ||
          seenNamesInBatch.contains(nameLower)) {
        continue;
      }

      if (barcode != null && barcode.isNotEmpty) {
        if (existingBarcodes.contains(barcode) ||
            seenBarcodesInBatch.contains(barcode)) {
          continue;
        }
        seenBarcodesInBatch.add(barcode);
      }

      seenNamesInBatch.add(nameLower);
      toImport.add(item);
    }

    if (toImport.isEmpty) return;

    const int batchSize = 500;
    for (var i = 0; i < toImport.length; i += batchSize) {
      final end =
          (i + batchSize < toImport.length) ? i + batchSize : toImport.length;
      final chunk = toImport.sublist(i, end);

      final batch = _db.batch();
      for (final item in chunk) {
        final p = item.keys.first;
        final units = item.values.first;
        final data = p.toMap();
        data['units'] = units.map((u) => u.toMap()).toList();
        batch.set(_productsCol.doc(p.id), data);

        if (p.barcode != null && p.barcode!.isNotEmpty) {
          final historyRef = _db
              .collection('users')
              .doc(_uid)
              .collection('barcode_history')
              .doc(p.barcode!.trim());
          batch.set(historyRef, {
            'barcode': p.barcode!.trim(),
            'productName': p.name,
            'productId': p.id,
            'usedAt': firestore.FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }
      await batch.commit();
    }
  }

  Future<void> updateProductsWithBarcodesBatch(List<Product> products) async {
    if (products.isEmpty) return;

    final batch = _db.batch();
    final now = DateTime.now();

    for (final p in products) {
      if (p.barcode == null || p.barcode!.isEmpty) continue;

      final docRef = _productsCol.doc(p.id);
      final data = p.toMap();
      data['units'] = p.units.map((u) => u.toMap()).toList();
      data['updated_at'] = now.toIso8601String();
      
      batch.set(docRef, data);

      final historyRef = _db
          .collection('users')
          .doc(_uid)
          .collection('barcode_history')
          .doc(p.barcode!.trim());
      batch.set(historyRef, {
        'barcode': p.barcode!.trim(),
        'productName': p.name,
        'productId': p.id,
        'usedAt': firestore.FieldValue.serverTimestamp(),
        'status': 'active',
      });
    }

    await batch.commit();
  }

  Future<void> updateStock(String productId, double delta) async {
    await _productsCol.doc(productId).update({
      'stock': firestore.FieldValue.increment(delta),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteProduct(String id) async {
    final doc = await _productsCol.doc(id).get();
    final data = doc.data() as Map<String, dynamic>?;
    final barcode = data?['barcode'] as String?;

    await _productsCol.doc(id).delete();

    if (barcode != null && barcode.isNotEmpty) {
      await _historyRepo.archiveBarcode(barcode);
    }

    try {
      await _storage.ref().child('users/$_uid/products/$id.jpg').delete();
    } catch (_) {}
  }

  Future<void> deleteProductsBatch(List<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_productsCol.doc(id));
    }
    await batch.commit();

    for (final id in ids) {
      try {
        await _storage.ref().child('users/$_uid/products/$id.jpg').delete();
      } catch (_) {}
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final historyRepo = ref.read(barcodeHistoryRepositoryProvider);
  return ProductRepository(user?.uid ?? 'unknown', historyRepo);
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

  Future<void> importProducts(
      List<Map<Product, List<ProductUnit>>> products) async {
    await _repo.saveProductsBatch(products);
  }

  Future<void> updateProductsBatch(List<Product> products) async {
    await _repo.updateProductsWithBarcodesBatch(products);
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
  }

  Future<void> deleteProductsBatch(List<String> ids) async {
    await _repo.deleteProductsBatch(ids);
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
