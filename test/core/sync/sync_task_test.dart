import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/sync/models/sync_task.dart';

void main() {
  group('SyncTask Model Tests', () {
    final now = DateTime.now();

    test('SyncTask serialization toMap and fromMap across SyncAction values', () {
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

    test('SyncTask copyWith updates retry count and clears last error when requested', () {
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

      final retryTask = task.copyWith(retryCount: 3, lastError: 'Service unavailable');
      expect(retryTask.retryCount, equals(3));
      expect(retryTask.lastError, equals('Service unavailable'));

      final clearedTask = retryTask.copyWith(clearLastError: true);
      expect(clearedTask.retryCount, equals(3));
      expect(clearedTask.lastError, isNull);
    });
  });
}
