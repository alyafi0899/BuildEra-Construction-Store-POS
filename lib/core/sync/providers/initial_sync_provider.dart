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
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      _loadSyncStatus(user.uid);
    }
    return InitialSyncState(isInitialSyncDone: true);
  }

  Future<void> _loadSyncStatus(String uid) async {
    final box = await LocalDatabase.openBox(uid, 'sync_meta');
    final isDone = box.get('initial_sync_done', defaultValue: false) as bool;
    state = state.copyWith(isInitialSyncDone: isDone);
  }

  Future<void> performInitialSync({bool force = false}) async {
    final auth = ref.read(authStateProvider).value;
    final isOnline = ref.read(isOnlineProvider);
    
    if (auth == null) return;

    if (!isOnline) {
      state = state.copyWith(error: 'Tidak ada koneksi internet. Silakan coba lagi nanti.');
      return;
    }

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // Bootstrap all repositories from Supabase
      await ref.read(productRepositoryProvider).bootstrap(force: force);
      await ref.read(transactionRepositoryProvider).bootstrap(force: force);
      await ref.read(debtRepositoryProvider).bootstrap(force: force);
      await ref.read(restockRepositoryProvider).bootstrap(force: force);
      await ref.read(barcodeHistoryRepositoryProvider).bootstrap(force: force);

      final box = await LocalDatabase.openBox(auth.uid, 'sync_meta');
      await box.put('initial_sync_done', true);

      state = state.copyWith(isSyncing: false, isInitialSyncDone: true);
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

final initialSyncProvider = NotifierProvider<InitialSyncNotifier, InitialSyncState>(InitialSyncNotifier.new);
