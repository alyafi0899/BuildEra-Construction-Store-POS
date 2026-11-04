import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildera/features/subscription/models/entitlement.dart';
import 'package:buildera/features/subscription/services/checkout_policy.dart';
import 'package:buildera/features/subscription/providers/bonus_quota_provider.dart';
import 'package:buildera/features/cashier/providers/cart_provider.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/shared/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tahap 6: Bonus Quota & CheckoutPolicy Tests', () {
    test('CheckoutPolicy allows extra transactions when bonusTransactions > 0', () {
      final entitlement = Entitlement.free();
      final cart = CartState(items: []);
      final nowJakarta = DateTime.now();

      // Create 10 dummy transactions today
      final todayTxs = List.generate(
        10,
        (i) => Transaction(
          id: 'tx-$i',
          invoiceNumber: 'INV-$i',
          subtotal: 1000,
          itemDiscountTotal: 0,
          transDiscountValue: 0,
          transDiscountType: DiscountType.fixed,
          transDiscountAmount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 1000,
          paymentMethod: 'Tunai',
          amountPaid: 1000,
          changeAmount: 0,
          createdAt: nowJakarta,
          updatedAt: nowJakarta,
        ),
      );

      // Without bonus: 10/10 reached -> rejected
      final resWithoutBonus = CheckoutPolicy.canCheckout(
        cart: cart,
        entitlement: entitlement,
        todayTransactions: todayTxs,
        currentJakartaTime: nowJakarta,
        bonusTransactions: 0,
      );
      expect(resWithoutBonus.allowed, isFalse);

      // With bonus +10: limit is now 20 -> allowed (10 remaining)
      final resWithBonus = CheckoutPolicy.canCheckout(
        cart: cart,
        entitlement: entitlement,
        todayTransactions: todayTxs,
        currentJakartaTime: nowJakarta,
        bonusTransactions: 10,
      );
      expect(resWithBonus.allowed, isTrue);
      expect(resWithBonus.remainingDailyTransactions, equals(10));
    });

    test('BonusQuotaNotifier grants reward bonus and enforces non-stacking & daily limit', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bonusQuotaProvider.notifier);

      expect(container.read(bonusQuotaProvider).isActive, isFalse);
      expect(notifier.canClaimReward(), isTrue);

      // Claim 1st bonus
      final granted1 = await notifier.grantRewardBonus();
      expect(granted1, isTrue);

      final state1 = container.read(bonusQuotaProvider);
      expect(state1.isActive, isTrue);
      expect(state1.activeBonusAmount, equals(10));
      expect(state1.rewardsClaimedToday, equals(1));

      // Attempting to claim while active bonus exists returns false (non-stacking)
      expect(notifier.canClaimReward(), isFalse);
      final granted2 = await notifier.grantRewardBonus();
      expect(granted2, isFalse);
    });
  });
}
