import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore hide Transaction;
import '../../../shared/models/product.dart';

final _uuid = Uuid();

// ── Repository ────────────────────────────────────────────────────────────

class ProductRepository {
  final _db = firestore.FirebaseFirestore.instance;

  Future<List<Product>> getAllProducts() async {
    final snapshot = await _db.collection('products').orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final unitsData = data['units'] as List? ?? [];
      final units = unitsData.map((u) => ProductUnit.fromMap(u as Map<String, dynamic>)).toList();
      return Product.fromMap(data, units: units);
    }).toList();
  }

  Future<void> saveProduct(Product p, List<ProductUnit> units) async {
    // 1. Check for duplicate barcode (if provided)
    if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
      final dupBarcode = await _db.collection('products')
          .where('barcode', isEqualTo: p.barcode!.trim())
          .limit(1)
          .get();
      if (dupBarcode.docs.isNotEmpty && dupBarcode.docs.first.id != p.id) {
        throw 'Barcode "${p.barcode}" sudah digunakan oleh produk lain';
      }
    }
    
    // 2. Check for duplicate name (case-insensitive check is hard in Firestore, usually names are unique-ish)
    final dupName = await _db.collection('products')
        .where('name', isEqualTo: p.name.trim())
        .limit(1)
        .get();
    if (dupName.docs.isNotEmpty && dupName.docs.first.id != p.id) {
      throw 'Produk dengan nama "${p.name}" sudah ada';
    }

    final data = p.toMap();
    data['units'] = units.map((u) => u.toMap()).toList();
    await _db.collection('products').doc(p.id).set(data);
  }

  Future<void> saveProductsBatch(List<Map<Product, List<ProductUnit>>> productsWithUnits) async {
    // To prevent duplicates during batch import, we fetch current state first
    final existing = await getAllProducts();
    final existingBarcodes = existing.map((e) => e.barcode?.trim()).whereType<String>().toSet();
    final existingNames = existing.map((e) => e.name.trim().toLowerCase()).toSet();

    final toImport = <Map<Product, List<ProductUnit>>>[];
    final seenBarcodesInBatch = <String>{};
    final seenNamesInBatch = <String>{};

    for (final item in productsWithUnits) {
      final p = item.keys.first;
      final nameLower = p.name.trim().toLowerCase();
      final barcode = p.barcode?.trim();

      // Check if duplicate name
      if (existingNames.contains(nameLower) || seenNamesInBatch.contains(nameLower)) {
        continue; // Skip duplicates
      }
      
      // Check if duplicate barcode
      if (barcode != null && barcode.isNotEmpty) {
        if (existingBarcodes.contains(barcode) || seenBarcodesInBatch.contains(barcode)) {
          continue; // Skip duplicates
        }
        seenBarcodesInBatch.add(barcode);
      }
      
      seenNamesInBatch.add(nameLower);
      toImport.add(item);
    }

    if (toImport.isEmpty) return;

    // Firestore batch limit is 500
    const int batchSize = 500;
    for (var i = 0; i < toImport.length; i += batchSize) {
      final end = (i + batchSize < toImport.length) ? i + batchSize : toImport.length;
      final chunk = toImport.sublist(i, end);
      
      final batch = _db.batch();
      for (final item in chunk) {
        final p = item.keys.first;
        final units = item.values.first;
        final data = p.toMap();
        data['units'] = units.map((u) => u.toMap()).toList();
        batch.set(_db.collection('products').doc(p.id), data);
      }
      await batch.commit();
    }
  }

  Future<void> updateStock(String productId, double delta) async {
    await _db.collection('products').doc(productId).update({
      'stock': firestore.FieldValue.increment(delta),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final productRepositoryProvider = Provider((_) => ProductRepository());

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(
    ProductsNotifier.new);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  ProductRepository get _repo => ref.read(productRepositoryProvider);

  @override
  Future<List<Product>> build() => _repo.getAllProducts();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getAllProducts);
  }

  Future<void> saveProduct(Product product, List<ProductUnit> units) async {
    await _repo.saveProduct(product, units);
    await refresh();
  }

  Future<void> importProducts(List<Map<Product, List<ProductUnit>>> products) async {
    await _repo.saveProductsBatch(products);
    await refresh();
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
    await refresh();
  }

  Future<void> adjustStock(String productId, double delta) async {
    await _repo.updateStock(productId, delta);
    await refresh();
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

Product blankProduct() => Product(
      id: _uuid.v4(),
      name: '',
      category: '',
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
