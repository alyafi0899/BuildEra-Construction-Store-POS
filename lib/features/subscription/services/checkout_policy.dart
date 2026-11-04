import '../../../shared/models/transaction.dart';
import '../../cashier/providers/cart_provider.dart';
import '../models/entitlement.dart';
import '../../../core/utils/trusted_time_helper.dart';

class CheckoutPolicyResult {
  final bool allowed;
  final String? reason;
  final int remainingDailyTransactions;

  const CheckoutPolicyResult({
    required this.allowed,
    this.reason,
    required this.remainingDailyTransactions,
  });

  static const CheckoutPolicyResult pass = CheckoutPolicyResult(
    allowed: true,
    remainingDailyTransactions: 999999,
  );
}

class CheckoutPolicy {
  /// Evaluates whether a cart checkout is allowed under the active Entitlement rules.
  static CheckoutPolicyResult canCheckout({
    required CartState cart,
    required Entitlement entitlement,
    required List<Transaction> todayTransactions,
    required DateTime currentJakartaTime,
    int bonusTransactions = 0,
  }) {
    // 1. Premium users have unlimited checkout capabilities
    if (entitlement.isPremium) {
      return CheckoutPolicyResult.pass;
    }

    // 2. Check items per transaction limit
    if (cart.items.length > entitlement.maxItemsPerTransaction) {
      return CheckoutPolicyResult(
        allowed: false,
        reason: 'Maks ${entitlement.maxItemsPerTransaction} item (Mode Gratis)',
        remainingDailyTransactions: 0,
      );
    }

    // 3. Check daily transactions limit
    final baseMaxDaily = entitlement.maxTransactionsPerDay;
    if (baseMaxDaily != null) {
      final effectiveMax = baseMaxDaily + bonusTransactions;

      // Filter transactions that occurred on the same Asia/Jakarta day
      final countToday = todayTransactions.where((t) {
        final tJakarta = t.createdAt.toUtc().add(const Duration(hours: 7));
        return TrustedTimeHelper.isSameJakartaDay(tJakarta, currentJakartaTime);
      }).length;

      final remaining = effectiveMax - countToday;

      if (remaining <= 0) {
        return CheckoutPolicyResult(
          allowed: false,
          reason: 'Limit $effectiveMax Transaksi Hari Ini',
          remainingDailyTransactions: 0,
        );
      }

      return CheckoutPolicyResult(
        allowed: true,
        remainingDailyTransactions: remaining,
      );
    }

    return CheckoutPolicyResult.pass;
  }
}
