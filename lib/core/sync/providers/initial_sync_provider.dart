import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';
import '../services/local_database.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/products/providers/barcode_history_provider.dart';
import '../../../features/payment/providers/transaction_provider.dart';
import '../../../features/debts/providers/debt_repository.dart';
import '../../../features/inventory/providers/restock_provider.dart';
import '../../../features/inventory/providers/bill_payment_provider.dart';
import '../../../features/products/providers/entity_provider.dart';

class InitialSyncState {
  final bool isInitialSyncDone;
  final bool isSyncing;
  final String? error;

  InitialSyncState({
    this.isInitialSyncDone = false,
    this.isSyncing = false,
    this.error,
  });

  InitialSyncState copyWith({
    bool? isInitialSyncDone,
    bool? isSyncing,
    String? error,
  }) {
    return InitialSyncState(
      isInitialSyncDone: isInitialSyncDone ?? this.isInitialSyncDone,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
    );
  }
}

class InitialSyncNotifier extends Notifier<InitialSyncState> {
  @override
  InitialSyncState build() {
    // We use a future here to avoid blocking build, but we want it to update state ASAP
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      _loadSyncStatus(user.uid);
    }
    return InitialSyncState(isInitialSyncDone: true); // Start as TRUE to avoid flashing dialog
  }

  Future<void> _loadSyncStatus(String uid) async {
    final box = await LocalDatabase.openBox(uid, 'sync_meta');
    final isDone = box.get('initial_sync_done', defaultValue: false) as bool;
    state = state.copyWith(isInitialSyncDone: isDone);
  }

  Future<void> markAsDone(String uid) async {
    final box = await LocalDatabase.openBox(uid, 'sync_meta');
    await box.put('initial_sync_done', true);
    state = state.copyWith(isInitialSyncDone: true, error: null);
  }

  Future<void> performInitialSync({bool force = false}) async {
    debugPrint('SYNC: Triggered performInitialSync(force: $force)');
    final auth = ref.read(authStateProvider).value;
    final isOnline = ref.read(isOnlineProvider);
    
    if (auth == null) {
      debugPrint('SYNC: No user found for initial sync');
      return;
    }

    if (!isOnline) {
      debugPrint('SYNC: Offline - Aborting');
      state = state.copyWith(error: 'Tidak ada koneksi internet. Silakan coba lagi nanti.');
      return;
    }

    debugPrint('SYNC: Starting Initial Download for user ${auth.uid}');
    state = state.copyWith(isSyncing: true, error: null);

    try {
      // 1. Products
      await ref.read(productRepositoryProvider).bootstrap(force: force);
      
      // 2. Transactions
      await ref.read(transactionRepositoryProvider).bootstrap(force: force);
      
      // 3. Debts & Customers
      await ref.read(debtRepositoryProvider).bootstrap(force: force);
      
      // 4. Restocks & Bill Payments
      await ref.read(restockRepositoryProvider).bootstrap(force: force);
      await ref.read(billPaymentRepositoryProvider).bootstrap(force: force);

      // 5. Barcode History
      await ref.read(barcodeHistoryRepositoryProvider).bootstrap(force: force);

      // 6. Entities (Suppliers & Shipping)
      await ref.read(entityRepositoryProvider).bootstrap(force: force);

      final box = await LocalDatabase.openBox(auth.uid, 'sync_meta');
      await box.put('initial_sync_done', true);

      state = state.copyWith(isSyncing: false, isInitialSyncDone: true);
      debugPrint('SYNC: Initial Download Completed');
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

final initialSyncProvider = NotifierProvider<InitialSyncNotifier, InitialSyncState>(InitialSyncNotifier.new);
