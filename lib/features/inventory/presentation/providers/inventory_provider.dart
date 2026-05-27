// lib/features/inventory/presentation/providers/inventory_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/presentation/providers/product_provider.dart';

export '../../../products/presentation/providers/product_provider.dart'
    show lowStockProductsProvider, allProductsProvider, productNotifierProvider;

final totalInventoryValueProvider = Provider<double>((ref) {
  return ref.watch(allProductsProvider).fold(0.0, (sum, p) => sum + p.stockQuantity * p.basePrice);
});

class CategoryStockSummary {
  final String category;
  final int productCount;
  final double totalValue;
  final int lowStockCount;

  const CategoryStockSummary({
    required this.category,
    required this.productCount,
    required this.totalValue,
    required this.lowStockCount,
  });
}

final categoryStockSummaryProvider = Provider<List<CategoryStockSummary>>((ref) {
  final products = ref.watch(allProductsProvider);
  final map = <String, CategoryStockSummary>{};
  for (final p in products) {
    final e = map[p.category];
    map[p.category] = CategoryStockSummary(
      category: p.category,
      productCount: (e?.productCount ?? 0) + 1,
      totalValue: (e?.totalValue ?? 0) + p.stockQuantity * p.basePrice,
      lowStockCount: (e?.lowStockCount ?? 0) + (p.isLowStock ? 1 : 0),
    );
  }
  return map.values.toList()..sort((a, b) => b.totalValue.compareTo(a.totalValue));
});
