enum SyncAction { create, update, delete, increment }

class SyncTask {
  final String id;
  final String collection;
  final String documentId;
  final SyncAction action;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const SyncTask({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.action,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection': collection,
      'document_id': documentId,
      'action': action.name,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory SyncTask.fromMap(Map<dynamic, dynamic> m) {
    return SyncTask(
      id:         m['id'] as String,
      collection: m['collection'] as String,
      documentId: m['document_id'] as String,
      action:     SyncAction.values.byName(m['action'] as String),
      data:       Map<String, dynamic>.from(m['data'] as Map),
      createdAt:  DateTime.parse(m['created_at'] as String),
      retryCount: m['retry_count'] as int? ?? 0,
      lastError:  m['last_error'] as String?,
    );
  }

  SyncTask copyWith({int? retryCount, String? lastError}) {
    return SyncTask(
      id:         id,
      collection: collection,
      documentId: documentId,
      action:     action,
      data:       data,
      createdAt:  createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError:  lastError ?? this.lastError,
    );
  }
}
