import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/products/providers/barcode_history_provider.dart';
import '../../../features/payment/providers/transaction_provider.dart';
import '../../../features/debts/providers/debt_repository.dart';
import '../../../features/inventory/providers/restock_provider.dart';

class InitialSyncNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> performInitialSync() async {
    final auth = ref.read(authStateProvider).value;
    final isOnline = ref.read(isOnlineProvider);
    
    if (auth == null || !isOnline) return;

    try {
      debugPrint('SYNC: Starting Initial Download for user ${auth.uid}');

      // 1. Products
      await ref.read(productRepositoryProvider).bootstrap();
      
      // 2. Transactions
      await ref.read(transactionRepositoryProvider).bootstrap();
      
      // 3. Debts & Customers
      await ref.read(debtRepositoryProvider).bootstrap();
      
      // 4. Restocks & Bill Payments
      await ref.read(restockRepositoryProvider).bootstrap();

      // 5. Barcode History
      await ref.read(barcodeHistoryRepositoryProvider).bootstrap();

      debugPrint('SYNC: Initial Download Completed');
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
    }
  }
}

final initialSyncProvider = NotifierProvider<InitialSyncNotifier, void>(InitialSyncNotifier.new);
