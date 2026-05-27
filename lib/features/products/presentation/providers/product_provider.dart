// lib/features/products/presentation/providers/product_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/hive/hive_models.dart';
import '../../../../data/hive/hive_service.dart';
import '../../domain/entities/product_entity.dart';

class ProductState {
  final List<ProductEntity> products;
  final bool loading;
  final String? error;

  const ProductState({this.products = const [], this.loading = false, this.error});

  ProductState copyWith({List<ProductEntity>? products, bool? loading, String? error}) =>
      ProductState(products: products ?? this.products, loading: loading ?? this.loading, error: error);
}

class ProductNotifier extends Notifier<ProductState> {
  @override
  ProductState build() {
    return ProductState(
      products: HiveService.getAllProducts().map((p) => p.toEntity()).toList(),
    );
  }

  void _reload() {
    state = ProductState(
      products: HiveService.getAllProducts().map((p) => p.toEntity()).toList(),
    );
  }

  Future<bool> addProduct({required ProductEntity product, required List<ProductUnitEntity> units}) async {
    try {
      final hiveProduct = HiveProduct.fromEntity(product, units: units.map(HiveProductUnit.fromEntity).toList());
      await HiveService.insertProduct(hiveProduct);
      _reload();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateProduct({required ProductEntity product, required List<ProductUnitEntity> units}) async {
    try {
      final existing = HiveService.getProductById(product.id!);
      if (existing == null) return false;
      final hiveUnits = units.asMap().entries.map((e) {
        final existingUnit = e.key < existing.units.length ? existing.units[e.key] : null;
        return HiveProductUnit(
          id: existingUnit?.id ?? (product.id! * 100 + e.key),
          productId: product.id!,
          unitName: e.value.unitName,
          conversionRatio: e.value.conversionRatio,
          sellingPrice: e.value.sellingPrice,
          isBaseUnit: e.value.isBaseUnit,
        );
      }).toList();
      await HiveService.updateProduct(HiveProduct(
        id: product.id!, name: product.name, category: product.category,
        barcode: product.barcode, basePrice: product.basePrice, baseUnit: product.baseUnit,
        stockQuantity: product.stockQuantity, description: product.description,
        isActive: product.isActive, units: hiveUnits,
      ));
      _reload();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await HiveService.deleteProduct(id);
      _reload();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> adjustStock(int productId, double adjustment) async {
    try {
      final product = HiveService.getProductById(productId);
      if (product == null) return false;
      final newStock = (product.stockQuantity + adjustment).clamp(0.0, double.infinity);
      await HiveService.updateStock(productId, newStock);
      _reload();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deductStock(int productId, double baseUnits) async => adjustStock(productId, -baseUnits);
}

final productNotifierProvider = NotifierProvider<ProductNotifier, ProductState>(ProductNotifier.new);

final allProductsProvider = Provider<List<ProductEntity>>((ref) => ref.watch(productNotifierProvider).products);

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<List<ProductEntity>>((ref) {
  final all = ref.watch(allProductsProvider);
  final q = ref.watch(productSearchQueryProvider).toLowerCase();
  if (q.isEmpty) return all;
  return all.where((p) =>
    p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false) || p.category.toLowerCase().contains(q)
  ).toList();
});

final lowStockProductsProvider = Provider<List<ProductEntity>>((ref) {
  return ref.watch(allProductsProvider).where((p) => p.isLowStock).toList()
    ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
});
