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
    final data = p.toMap();
    data['units'] = units.map((u) => u.toMap()).toList();
    await _db.collection('products').doc(p.id).set(data);
  }

  Future<void> saveProductsBatch(List<Map<Product, List<ProductUnit>>> productsWithUnits) async {
    // Firestore batch limit is 500
    const int batchSize = 500;
    for (var i = 0; i < productsWithUnits.length; i += batchSize) {
      final end = (i + batchSize < productsWithUnits.length) ? i + batchSize : productsWithUnits.length;
      final chunk = productsWithUnits.sublist(i, end);
      
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
