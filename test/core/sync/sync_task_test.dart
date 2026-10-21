import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/sync/models/sync_task.dart';

void main() {
  group('SyncTask Model Tests', () {
    final now = DateTime.now();

    test('SyncTask serialization toMap and fromMap across SyncAction values',
        () {
      for (final action in SyncAction.values) {
        final task = SyncTask(
          id: 'task-001',
          collection: 'products',
          documentId: 'doc-123',
          action: action,
          data: {'name': 'Semen', 'stock': 10},
          createdAt: now,
          retryCount: 1,
          lastError: 'Network error',
        );

        final map = task.toMap();
        expect(map['id'], equals('task-001'));
        expect(map['action'], equals(action.name));
        expect(map['retry_count'], equals(1));
        expect(map['last_error'], equals('Network error'));

        final restored = SyncTask.fromMap(map);
        expect(restored.id, equals('task-001'));
        expect(restored.collection, equals('products'));
        expect(restored.documentId, equals('doc-123'));
        expect(restored.action, equals(action));
        expect(restored.data['name'], equals('Semen'));
        expect(restored.retryCount, equals(1));
        expect(restored.lastError, equals('Network error'));
      }
    });

    test(
        'SyncTask copyWith updates retry count and clears last error when requested',
        () {
      final task = SyncTask(
        id: 'task-002',
        collection: 'transactions',
        documentId: 'tx-555',
        action: SyncAction.create,
        data: {'total': 100000},
        createdAt: now,
        retryCount: 2,
        lastError: 'Timeout',
      );

      final retryTask =
          task.copyWith(retryCount: 3, lastError: 'Service unavailable');
      expect(retryTask.retryCount, equals(3));
      expect(retryTask.lastError, equals('Service unavailable'));

      final clearedTask = retryTask.copyWith(clearLastError: true);
      expect(clearedTask.retryCount, equals(3));
      expect(clearedTask.lastError, isNull);
    });

    test('cloud schema errors defer and retain a task after repeated attempts',
        () {
      final schemaErrors = [
        Exception('PostgREST PGRST205: table missing from schema cache'),
        Exception('PostgREST PGRST204: column not found'),
      ];
      var task = SyncTask(
        id: 'task-schema',
        collection: 'transaction_items',
        documentId: 'item-1',
        action: SyncAction.create,
        data: {'id': 'item-1'},
        createdAt: now,
      );

      for (var attempt = 1; attempt <= 7; attempt++) {
        final error = schemaErrors[(attempt - 1) % schemaErrors.length];
        final result = syncTaskFailureResult(
          task,
          error,
          now: now,
        );
        expect(result.disposition, SyncTaskFailureDisposition.deferForSchema);
        expect(isCloudSchemaNotReadyError(error), isTrue);

        expect(result.task, isNotNull);
        task = SyncTask.fromMap(result.task!.toMap());

        task = SyncTask.fromMap(task.toMap());

        expect(task.retryCount, attempt);
        expect(task.nextRetryAt, now.add(const Duration(minutes: 15)));
        expect(task.schemaRetryLogged, isTrue);
        expect(task.lastError, error.toString());
      }
    });

    test('non-schema failures retain the existing retry limit behavior', () {
      var task = SyncTask(
        id: 'task-network',
        collection: 'transactions',
        documentId: 'tx-1',
        action: SyncAction.create,
        data: const {},
        createdAt: now,
      );
      final error = Exception('Network timeout');

      for (var retry = 0; retry < 4; retry++) {
        final result = syncTaskFailureResult(
          task,
          error,
          now: now,
        );
        expect(result.disposition, SyncTaskFailureDisposition.retry);
        expect(result.task, isNotNull);
        task = result.task!;
      }
      final result = syncTaskFailureResult(
        task,
        error,
        now: now,
      );
      expect(result.disposition, SyncTaskFailureDisposition.discard);
      expect(result.task, isNull);
      expect(isCloudSchemaNotReadyError(error), isFalse);
    });
  });
}
