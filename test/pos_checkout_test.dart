import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/shared/models/product.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/features/cashier/providers/cart_provider.dart';

void main() {
  group('POS Cart & Checkout Operations', () {
    final now = DateTime.now();
    final testProduct = Product(
      id: 'prod-1',
      name: 'Semen Gresik 50kg',
      category: 'Semen',
      costPrice: 50000,
      basePrice: 65000,
      baseUnit: 'sak',
      stock: 100,
      createdAt: now,
      updatedAt: now,
      units: const [
        ProductUnit(
          id: 'unit-base',
          productId: 'prod-1',
          unitName: 'sak',
          conversionRate: 1,
          sellPrice: 65000,
        ),
      ],
    );

    test('CartItem price and profit calculations', () {
      final item = CartItem(
        id: 'item-1',
        product: testProduct,
        selectedUnit: testProduct.units.first,
        quantity: 2,
        costPrice: 50000,
        originalPrice: 65000,
        soldPrice: 65000,
      );

      expect(item.totalBeforeDiscount, equals(130000));
      expect(item.totalCost, equals(100000));
      expect(item.totalDiscount, equals(0));
      expect(item.subtotal, equals(130000));
      expect(item.profit, equals(30000));
      expect(item.isOverridden, isFalse);
    });

    test('CartItem with percentage discount', () {
      final item = CartItem(
        id: 'item-2',
        product: testProduct,
        selectedUnit: testProduct.units.first,
        quantity: 2,
        costPrice: 50000,
        originalPrice: 65000,
        soldPrice: 65000,
        discountValue: 10, // 10%
        discountType: DiscountType.percentage,
      );

      // 10% of 65,000 = 6,500 per unit -> 13,000 total discount for 2 units
      expect(item.totalDiscount, equals(13000));
      expect(item.subtotal, equals(117000));
      expect(item.profit, equals(17000));
    });

    test('CartState totals, tax, and shipping fee logic', () {
      final item1 = CartItem(
        id: 'item-1',
        product: testProduct,
        selectedUnit: testProduct.units.first,
        quantity: 2,
        costPrice: 50000,
        originalPrice: 65000,
        soldPrice: 65000,
      );

      final cart = CartState(
        items: [item1],
        transDiscountValue: 5000,
        transDiscountType: DiscountType.fixed,
        taxRate: 0.11,
        taxEnabled: true,
      );

      expect(cart.grossSubtotal, equals(130000));
      expect(cart.itemDiscountTotal, equals(0));
      expect(cart.netSubtotal, equals(130000));
      expect(cart.transDiscountAmount, equals(5000));
      // Taxable amount = netSubtotal (130,000) - transDiscount (5,000) = 125,000
      // Tax 11% of 125,000 = 13,750
      expect(cart.taxAmount, equals(13750));
      // Total = 125,000 + 13,750 = 138,750
      expect(cart.total, equals(138750));
    });

    test('Cash payment change calculation', () {
      final item1 = CartItem(
        id: 'item-1',
        product: testProduct,
        selectedUnit: testProduct.units.first,
        quantity: 1,
        costPrice: 50000,
        originalPrice: 65000,
        soldPrice: 65000,
      );

      final cart = CartState(items: [item1]);
      const shippingFee = 5000.0;
      final finalTotal = cart.total + shippingFee; // 65,000 + 5,000 = 70,000
      const amountPaid = 100000.0;
      final change = amountPaid - finalTotal;

      expect(finalTotal, equals(70000));
      expect(change, equals(30000));
    });
  });
}
