import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:buildera/shared/models/product.dart';
import 'package:buildera/features/products/models/product_financials.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/features/cashier/providers/cart_provider.dart';
import 'package:buildera/features/cashier/presentation/widgets/cart_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProduct = Product(
    id: 'p1',
    name: 'Semen Gresik 50kg',
    category: 'Semen',
    costPrice: 55000,
    basePrice: 65000,
    baseUnit: 'sak',
    stock: 100,
    financials: const ProductFinancials(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Tahap 2: Cart Panel Item Tile Field Inputs', () {
    testWidgets('Price formatting, empty clearing on focus, and blur restoration (Compact Layout)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProduct);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: Consumer(
                  builder: (context, ref, _) {
                    final items = ref.watch(cartProvider.select((s) => s.items));
                    if (items.isEmpty) return const SizedBox.shrink();
                    return CartItemTile(itemId: items.first.id);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final priceFields = find.byType(TextField);
      expect(priceFields, findsNWidgets(3)); // Qty, Price, Discount

      final priceField = priceFields.at(1);

      // Verify formatted initial price 65.000
      expect(tester.widget<TextField>(priceField).controller?.text, equals('65.000'));

      // Focus and clear price text
      await tester.tap(priceField);
      await tester.pump();
      await tester.enterText(priceField, '');
      await tester.pump();

      // Field should stay empty while focused, NOT instantly revert to 65.000
      expect(tester.widget<TextField>(priceField).controller?.text, equals(''));

      // Type 1500000
      await tester.enterText(priceField, '1500000');
      await tester.pump();

      // Controller should show formatted 1.500.000
      expect(tester.widget<TextField>(priceField).controller?.text, equals('1.500.000'));

      // Unfocus (blur)
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Item in cart updated to 1500000
      final cartItem = container.read(cartProvider).items.first;
      expect(cartItem.soldPrice, equals(1500000.0));
    });

    testWidgets('Empty Qty on blur restores old Qty [Perubahan C], and Qty 0 deletes item', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProduct);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: Consumer(
                  builder: (context, ref, _) {
                    final items = ref.watch(cartProvider.select((s) => s.items));
                    if (items.isEmpty) return const SizedBox.shrink();
                    return CartItemTile(itemId: items.first.id);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final qtyField = find.byType(TextField).at(0);

      // Focus and clear Qty
      await tester.tap(qtyField);
      await tester.pump();
      await tester.enterText(qtyField, '');
      await tester.pump();

      // Unfocus (blur) without typing anything
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Item should NOT be deleted, Qty should be restored to 1
      expect(container.read(cartProvider).items.length, equals(1));
      expect(tester.widget<TextField>(qtyField).controller?.text, equals('1'));

      // Now enter explicit "0" and submit/blur
      await tester.tap(qtyField);
      await tester.pump();
      await tester.enterText(qtyField, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Explicit "0" DELETES item
      expect(container.read(cartProvider).items.isEmpty, isTrue);
    });

    testWidgets('Decimal percentage discount 2,5 formats and saves correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProduct);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: Consumer(
                  builder: (context, ref, _) {
                    final items = ref.watch(cartProvider.select((s) => s.items));
                    if (items.isEmpty) return const SizedBox.shrink();
                    return CartItemTile(itemId: items.first.id);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Change discount type to %
      final dropdown = find.byType(DropdownButton<DiscountType>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('%').last);
      await tester.pumpAndSettle();

      final discField = find.byType(TextField).at(2);

      // Type 2,5 in percentage discount
      await tester.tap(discField);
      await tester.pump();
      await tester.enterText(discField, '2,5');
      await tester.pump();

      // Unfocus
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final cartItem = container.read(cartProvider).items.first;
      expect(cartItem.discountType, equals(DiscountType.percentage));
      expect(cartItem.discountValue, equals(2.5));
      expect(tester.widget<TextField>(discField).controller?.text, equals('2,5'));
    });
  });
}
