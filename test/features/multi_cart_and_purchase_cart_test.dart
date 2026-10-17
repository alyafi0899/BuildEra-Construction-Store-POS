import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/shared/models/product.dart';
import 'package:buildera/features/cashier/providers/cart_provider.dart';
import 'package:buildera/features/cashier/providers/multi_cart_provider.dart';
import 'package:buildera/features/purchase/providers/purchase_cart_provider.dart';

void main() {
  final now = DateTime.now();

  final productA = Product(
    id: 'prod-a',
    name: 'Paku Kayu 3 inch',
    category: 'Paku',
    costPrice: 15000,
    basePrice: 20000,
    baseUnit: 'kg',
    stock: 50,
    createdAt: now,
    updatedAt: now,
    units: const [
      ProductUnit(
        id: 'unit-a1',
        productId: 'prod-a',
        unitName: 'kg',
        conversionRate: 1,
        sellPrice: 20000,
      ),
      ProductUnit(
        id: 'unit-a2',
        productId: 'prod-a',
        unitName: 'dus',
        conversionRate: 10,
        sellPrice: 190000,
      ),
    ],
  );

  final productB = Product(
    id: 'prod-b',
    name: 'Pipa PVC 3/4 inch',
    category: 'Pipa',
    costPrice: 25000,
    basePrice: 35000,
    baseUnit: 'batang',
    stock: 30,
    createdAt: now,
    updatedAt: now,
    units: const [
      ProductUnit(
        id: 'unit-b1',
        productId: 'prod-b',
        unitName: 'batang',
        conversionRate: 1,
        sellPrice: 35000,
      ),
    ],
  );

  group('MultiCartNotifier Tests', () {
    test('initial state starts with 1 empty cart tab at index 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final multiCart = container.read(multiCartProvider);
      expect(multiCart.carts.length, equals(1));
      expect(multiCart.activeIndex, equals(0));
    });

    test('addNewCart creates a new tab and switches active index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add product to Cart 0
      container.read(cartProvider.notifier).addProduct(productA);
      expect(container.read(cartProvider).items.length, equals(1));

      // Add new cart tab
      container.read(multiCartProvider.notifier).addNewCart();

      final multiCart = container.read(multiCartProvider);
      expect(multiCart.carts.length, equals(2));
      expect(multiCart.activeIndex, equals(1));

      // Active cart (Cart 1) should be clean and empty
      expect(container.read(cartProvider).items, isEmpty);
    });

    test('switchCart switches active tab and preserves cart state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add productA to Cart 0
      container.read(cartProvider.notifier).addProduct(productA);

      // Add Cart 1 and add productB to Cart 1
      container.read(multiCartProvider.notifier).addNewCart();
      container.read(cartProvider.notifier).addProduct(productB);

      expect(container.read(cartProvider).items.single.product.id, equals('prod-b'));

      // Switch back to Cart 0
      container.read(multiCartProvider.notifier).switchCart(0);

      expect(container.read(multiCartProvider).activeIndex, equals(0));
      expect(container.read(cartProvider).items.single.product.id, equals('prod-a'));
    });

    test('removeCart removes active tab and switches to adjacent tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Create 2 carts
      container.read(multiCartProvider.notifier).addNewCart(); // now length 2, activeIndex 1
      expect(container.read(multiCartProvider).carts.length, equals(2));

      // Remove Cart 1
      container.read(multiCartProvider.notifier).removeCart(1);

      final multiCart = container.read(multiCartProvider);
      expect(multiCart.carts.length, equals(1));
      expect(multiCart.activeIndex, equals(0));
    });

    test('cannot remove sole remaining cart tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(multiCartProvider.notifier).removeCart(0);

      expect(container.read(multiCartProvider).carts.length, equals(1));
    });
  });

  group('PurchaseCartNotifier Tests', () {
    test('addProduct adds product with correct unit purchase price', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final purchaseNotifier = container.read(purchaseCartProvider.notifier);
      purchaseNotifier.addProduct(productA);

      final state = container.read(purchaseCartProvider);
      expect(state.items.length, equals(1));
      expect(state.items.single.product.id, equals('prod-a'));
      expect(state.items.single.quantity, equals(1.0));
      expect(state.items.single.purchasePrice, equals(15000));
      expect(state.subtotal, equals(15000));
    });

    test('addProduct with secondary unit uses unit conversion rate', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final purchaseNotifier = container.read(purchaseCartProvider.notifier);
      final dusUnit = productA.units[1]; // dus (conversion rate 10)
      purchaseNotifier.addProduct(productA, unit: dusUnit);

      final state = container.read(purchaseCartProvider);
      expect(state.items.length, equals(1));
      expect(state.items.single.unit.unitName, equals('dus'));
      expect(state.items.single.purchasePrice, equals(150000)); // 15000 * 10
      expect(state.subtotal, equals(150000));
    });

    test('updateQuantity, updatePurchasePrice, setShippingFee, and clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final purchaseNotifier = container.read(purchaseCartProvider.notifier);
      purchaseNotifier.addProduct(productA);
      final itemId = container.read(purchaseCartProvider).items.single.id;

      // Update quantity to 5
      purchaseNotifier.updateQuantity(itemId, 5);
      expect(container.read(purchaseCartProvider).items.single.quantity, equals(5));
      expect(container.read(purchaseCartProvider).subtotal, equals(75000)); // 5 * 15000

      // Custom price update
      purchaseNotifier.updatePurchasePrice(itemId, 14000);
      expect(container.read(purchaseCartProvider).subtotal, equals(70000)); // 5 * 14000

      // Add shipping fee
      purchaseNotifier.setShippingFee(25000);
      expect(container.read(purchaseCartProvider).shippingFee, equals(25000));
      expect(container.read(purchaseCartProvider).total, equals(95000));

      // Supplier
      purchaseNotifier.setSupplier('sup-1', 'PT Material');
      expect(container.read(purchaseCartProvider).supplierName, equals('PT Material'));

      // Clear
      purchaseNotifier.clear();
      expect(container.read(purchaseCartProvider).isEmpty, isTrue);
      expect(container.read(purchaseCartProvider).supplierId, isNull);
    });
  });
}
