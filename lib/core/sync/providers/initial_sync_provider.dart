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
import '../../../features/products/providers/entity_provider.dart';
import '../../../features/purchase/providers/purchase_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';

class InitialSyncState {
  final bool isInitialSyncDone;
  final bool isSyncing;
  final bool isStatusLoaded;
  final String? error;
  final double progress;
  final String? currentTask;

  InitialSyncState({
    this.isInitialSyncDone = false,
    this.isSyncing = false,
    this.isStatusLoaded = false,
    this.error,
    this.progress = 0,
    this.currentTask,
  });

  InitialSyncState copyWith({
    bool? isInitialSyncDone,
    bool? isSyncing,
    bool? isStatusLoaded,
    String? error,
    bool clearError = false,
    double? progress,
    String? currentTask,
  }) {
    return InitialSyncState(
      isInitialSyncDone: isInitialSyncDone ?? this.isInitialSyncDone,
      isSyncing: isSyncing ?? this.isSyncing,
      isStatusLoaded: isStatusLoaded ?? this.isStatusLoaded,
      error: clearError ? null : (error ?? this.error),
      progress: progress ?? this.progress,
      currentTask: currentTask ?? this.currentTask,
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
    return InitialSyncState(isStatusLoaded: false, isInitialSyncDone: true);
  }

  Future<void> _loadSyncStatus(String uid) async {
    final box = await LocalDatabase.openBox(uid, 'sync_meta');
    final isDone = box.get('initial_sync_done', defaultValue: false) as bool;
    state = state.copyWith(isInitialSyncDone: isDone, isStatusLoaded: true);
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

    state = state.copyWith(
      isSyncing: true,
      clearError: true,
      currentTask: 'Memeriksa pembaruan...',
    );

    try {
      // 1. Process local outgoing changes first
      final syncNotifier = ref.read(syncProvider.notifier);
      await syncNotifier.processQueue();
      final queueError = ref.read(syncProvider).lastError;

      // Pull remote changes and use the successful pull time as its checkpoint.
      final deltaSucceeded = await syncNotifier.fetchDeltas(DateTime.now());
      if (queueError != null || !deltaSucceeded) {
        throw Exception(
          queueError ?? ref.read(syncProvider).lastError ?? 'Pull data gagal.',
        );
      }
      await ref.read(settingsProvider.notifier).refreshFromRemote();

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
      state = state.copyWith(
          error: 'Tidak ada koneksi internet. Silakan coba lagi nanti.');
      return;
    }

    debugPrint('SYNC: Starting Initial Download for user ${auth.uid}');
    state = state.copyWith(
      isSyncing: true,
      clearError: true,
      progress: 0,
      currentTask: 'Menyiapkan...',
    );

    try {
      int completed = 0;
      const total = 7;

      Future<bool> runBootstrap(
        String name,
        Future<void> Function({bool force}) bootstrapFn,
      ) async {
        var succeeded = true;
        try {
          await bootstrapFn(force: force);
        } catch (e) {
          debugPrint('SYNC Error in $name: $e');
          succeeded = false;
        } finally {
          completed++;
          state = state.copyWith(
            progress: completed / total,
            currentTask: 'Mengunduh $name... ($completed/$total)',
          );
        }
        return succeeded;
      }

      final bootstrapResults = await Future.wait([
        runBootstrap('Produk', ref.read(productRepositoryProvider).bootstrap),
        runBootstrap(
            'Transaksi', ref.read(transactionRepositoryProvider).bootstrap),
        runBootstrap(
            'Piutang & Pelanggan', ref.read(debtRepositoryProvider).bootstrap),
        runBootstrap(
            'Stok & Pembayaran', ref.read(restockRepositoryProvider).bootstrap),
        runBootstrap('Riwayat Barcode',
            ref.read(barcodeHistoryRepositoryProvider).bootstrap),
        runBootstrap('Supplier & Ekspedisi',
            ref.read(entityRepositoryProvider).bootstrap),
        runBootstrap(
            'Pembelian', ref.read(purchaseRepositoryProvider).bootstrap),
      ]);

      final taskNames = [
        'Produk',
        'Transaksi',
        'Piutang & Pelanggan',
        'Stok & Pembayaran',
        'Riwayat Barcode',
        'Supplier & Ekspedisi',
        'Pembelian',
      ];
      final failedTasks = [
        for (var index = 0; index < bootstrapResults.length; index++)
          if (!bootstrapResults[index]) taskNames[index],
      ];

      if (failedTasks.isNotEmpty) {
        state = state.copyWith(
          isSyncing: false,
          isInitialSyncDone: false,
          error:
              'Gagal mengunduh: ${failedTasks.join(', ')}. Silakan coba lagi.',
          currentTask: 'Sebagian data belum tersinkron',
        );
        return;
      }

      final box = await LocalDatabase.openBox(auth.uid, 'sync_meta');
      await box.put('initial_sync_done', true);

      state = state.copyWith(
          isSyncing: false,
          isInitialSyncDone: true,
          progress: 1.0,
          currentTask: 'Selesai');
      debugPrint('SYNC: Initial Download Completed');
    } catch (e) {
      debugPrint('SYNC: Initial Download Error: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

final initialSyncProvider =
    NotifierProvider<InitialSyncNotifier, InitialSyncState>(
        InitialSyncNotifier.new);
