import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';
import 'sync_provider.dart';
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
  final double progress;
  final String? currentTask;

  InitialSyncState({
    this.isInitialSyncDone = false,
    this.isSyncing = false,
    this.error,
    this.progress = 0,
    this.currentTask,
  });

  InitialSyncState copyWith({
    bool? isInitialSyncDone,
    bool? isSyncing,
    String? error,
    double? progress,
    String? currentTask,
  }) {
    return InitialSyncState(
      isInitialSyncDone: isInitialSyncDone ?? this.isInitialSyncDone,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      currentTask: currentTask ?? this.currentTask,
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

  Future<void> markAsDone() async {
    final auth = ref.read(authStateProvider).value;
    if (auth == null) return;
    
    final box = await LocalDatabase.openBox(auth.uid, 'sync_meta');
    await box.put('initial_sync_done', true);
    state = state.copyWith(isInitialSyncDone: true);
    debugPrint('SYNC: Initial sync marked as DONE (New Account Flow)');
  }

  Future<void> triggerManualSync() async {
    final auth = ref.read(authStateProvider).value;
    final isOnline = ref.read(isOnlineProvider);
    
    if (auth == null || !isOnline || state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null, currentTask: 'Memeriksa pembaruan...');
    
    try {
      // 1. Process local outgoing changes first
      await ref.read(syncProvider.notifier).processQueue();
      
      // 2. Fetch remote incoming changes (Delta Sync)
      // We pass a very old timestamp or the actual last sync to ensure we get what's missing
      final localLastSyncRaw = await LocalDatabase.getMetadata(auth.uid, 'last_remote_sync');
      final lastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);
      
      await ref.read(syncProvider.notifier).fetchDeltas(lastSync);
      
      state = state.copyWith(isSyncing: false, currentTask: 'Selesai');
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
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
    state = state.copyWith(isSyncing: true, error: null, progress: 0, currentTask: 'Menyiapkan...');

    try {
      int completed = 0;
      const total = 5;

      Future<void> runBootstrap(String name, Future<void> Function({bool force}) bootstrapFn) async {
        try {
          await bootstrapFn(force: force);
        } catch (e) {
          debugPrint('SYNC Error in $name: $e');
        } finally {
          completed++;
          state = state.copyWith(
            progress: completed / total,
            currentTask: 'Mengunduh $name... ($completed/$total)',
          );
        }
      }

      await Future.wait([
        runBootstrap('Produk', ref.read(productRepositoryProvider).bootstrap),
        runBootstrap('Transaksi', ref.read(transactionRepositoryProvider).bootstrap),
        runBootstrap('Piutang & Pelanggan', ref.read(debtRepositoryProvider).bootstrap),
        runBootstrap('Stok & Pembayaran', ref.read(restockRepositoryProvider).bootstrap),
        runBootstrap('Riwayat Barcode', ref.read(barcodeHistoryRepositoryProvider).bootstrap),
      ]);

      final box = await LocalDatabase.openBox(auth.uid, 'sync_meta');
      await box.put('initial_sync_done', true);

      state = state.copyWith(isSyncing: false, isInitialSyncDone: true, progress: 1.0, currentTask: 'Selesai');
      debugPrint('SYNC: Initial Download Completed');
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

final initialSyncProvider = NotifierProvider<InitialSyncNotifier, InitialSyncState>(InitialSyncNotifier.new);
