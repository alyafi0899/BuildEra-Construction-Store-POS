import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:buildera/core/sync/widgets/sync_status_bar.dart';
import 'package:buildera/core/sync/providers/connectivity_provider.dart';
import 'package:buildera/core/sync/providers/sync_provider.dart';
import 'package:buildera/core/sync/providers/initial_sync_provider.dart';

class FakeSyncNotifier extends SyncNotifier {
  final SyncState _initialState;
  FakeSyncNotifier(this._initialState);

  @override
  SyncState build() => _initialState;
}

class FakeInitialSyncNotifier extends InitialSyncNotifier {
  final InitialSyncState _initialState;
  FakeInitialSyncNotifier(this._initialState);

  @override
  InitialSyncState build() => _initialState;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('SyncStatusBar renders Offline when connectivity is offline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => false),
          syncProvider.overrideWith(() => FakeSyncNotifier(const SyncState())),
          initialSyncProvider.overrideWith(() => FakeInitialSyncNotifier(InitialSyncState())),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusBar(),
          ),
        ),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Bekerja secara lokal'), findsOneWidget);
  });

  testWidgets('SyncStatusBar renders Tersinkronisasi when online and fully synced', (tester) async {
    final now = DateTime(2026, 10, 17, 10, 0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => true),
          syncProvider.overrideWith(() => FakeSyncNotifier(SyncState(lastSyncAt: now))),
          initialSyncProvider.overrideWith(() => FakeInitialSyncNotifier(InitialSyncState())),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusBar(),
          ),
        ),
      ),
    );

    expect(find.text('Tersinkronisasi'), findsOneWidget);
  });

  testWidgets('SyncStatusBar renders Sedang Sinkronisasi when pendingCount > 0', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => true),
          syncProvider.overrideWith(() => FakeSyncNotifier(const SyncState(pendingCount: 5, isSyncing: true))),
          initialSyncProvider.overrideWith(() => FakeInitialSyncNotifier(InitialSyncState())),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusBar(),
          ),
        ),
      ),
    );

    expect(find.text('Sedang Sinkronisasi'), findsOneWidget);
    expect(find.text('5 data tersisa'), findsOneWidget);
  });
}
