import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/products/providers/barcode_history_provider.dart';
import '../../../features/payment/providers/transaction_provider.dart';
import '../../../features/debts/providers/debt_repository.dart';
import '../../../features/inventory/providers/restock_provider.dart';

class InitialSyncState {
  final bool isSyncing;
  final double progress;
  final String currentStep;
  final String? error;
  final bool isCompleted;

  const InitialSyncState({
    this.isSyncing = false,
    this.progress = 0,
    this.currentStep = '',
    this.error,
    this.isCompleted = false,
  });

  InitialSyncState copyWith({
    bool? isSyncing,
    double? progress,
    String? currentStep,
    String? error,
    bool? isCompleted,
  }) {
    return InitialSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      error: error ?? this.error,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class InitialSyncNotifier extends Notifier<InitialSyncState> {
  @override
  InitialSyncState build() => const InitialSyncState();

  Future<void> performInitialSync() async {
    final auth = ref.read(authStateProvider).value;
    final isOnline = ref.read(isOnlineProvider);
    
    if (auth == null || !isOnline) return;

    // Check if we already have vital data (Local First check)
    final productRepo = ref.read(productRepositoryProvider);
    final products = await productRepo.getAllProducts();
    
    if (products.isNotEmpty) {
      // Data already exists, sync in background without blocking
      _backgroundSync(auth.uid);
      return;
    }

    // No data found, block UI for initial sync
    state = state.copyWith(isSyncing: true, currentStep: 'Menghubungkan ke Server...', progress: 0.1);

    try {
      debugPrint('SYNC: Starting Initial Download for user ${auth.uid}');

      // 1. Products (Vital)
      state = state.copyWith(currentStep: 'Mengunduh Data Produk...', progress: 0.2);
      await ref.read(productRepositoryProvider).bootstrap();
      
      // 2. Transactions
      state = state.copyWith(currentStep: 'Mengunduh Riwayat Transaksi...', progress: 0.4);
      await ref.read(transactionRepositoryProvider).bootstrap();
      
      // 3. Debts & Customers
      state = state.copyWith(currentStep: 'Mengunduh Data Pelanggan & Piutang...', progress: 0.6);
      await ref.read(debtRepositoryProvider).bootstrap();
      
      // 4. Restocks & Bill Payments
      state = state.copyWith(currentStep: 'Mengunduh Riwayat Inventori...', progress: 0.8);
      await ref.read(restockRepositoryProvider).bootstrap();

      // 5. Barcode History
      state = state.copyWith(currentStep: 'Menyelesaikan Sinkronisasi...', progress: 0.95);
      await ref.read(barcodeHistoryRepositoryProvider).bootstrap();

      debugPrint('SYNC: Initial Download Completed');
      state = state.copyWith(isSyncing: false, isCompleted: true, progress: 1.0);
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }

  Future<void> _backgroundSync(String uid) async {
    // Background sync doesn't update state to avoid blocking UI
    try {
       // We can still call bootstrap, repositories should handle incremental logic 
       // or skip if box is not empty (as per current implementation)
       // Future improvement: Implement real incremental sync here
       await ref.read(productRepositoryProvider).bootstrap();
       await ref.read(transactionRepositoryProvider).bootstrap();
       await ref.read(debtRepositoryProvider).bootstrap();
       await ref.read(restockRepositoryProvider).bootstrap();
       await ref.read(barcodeHistoryRepositoryProvider).bootstrap();
    } catch (e) {
      debugPrint('SYNC: Background Sync Error: $e');
    }
  }
}

final initialSyncProvider = NotifierProvider<InitialSyncNotifier, InitialSyncState>(InitialSyncNotifier.new);
