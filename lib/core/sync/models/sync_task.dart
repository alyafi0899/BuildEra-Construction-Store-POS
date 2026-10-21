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
  final DateTime? nextRetryAt;
  final bool schemaRetryLogged;

  const SyncTask({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.action,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.nextRetryAt,
    this.schemaRetryLogged = false,
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
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'schema_retry_logged': schemaRetryLogged,
    };
  }

  factory SyncTask.fromMap(Map<dynamic, dynamic> m) {
    return SyncTask(
      id: m['id'] as String,
      collection: m['collection'] as String,
      documentId: m['document_id'] as String,
      action: SyncAction.values.byName(m['action'] as String),
      data: Map<String, dynamic>.from(m['data'] as Map),
      createdAt: DateTime.parse(m['created_at'] as String),
      retryCount: m['retry_count'] as int? ?? 0,
      lastError: m['last_error'] as String?,
      nextRetryAt: m['next_retry_at'] == null
          ? null
          : DateTime.parse(m['next_retry_at'] as String),
      schemaRetryLogged: m['schema_retry_logged'] as bool? ?? false,
    );
  }

  SyncTask copyWith({
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    DateTime? nextRetryAt,
    bool? schemaRetryLogged,
  }) {
    return SyncTask(
      id: id,
      collection: collection,
      documentId: documentId,
      action: action,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      schemaRetryLogged: schemaRetryLogged ?? this.schemaRetryLogged,
    );
  }

  SyncTask deferAfterSchemaError(String error, DateTime retryAt) => copyWith(
        retryCount: retryCount + 1,
        lastError: error,
        nextRetryAt: retryAt,
        schemaRetryLogged: true,
      );
}

enum SyncTaskFailureDisposition { retry, deferForSchema, discard }

class SyncTaskFailureResult {
  final SyncTaskFailureDisposition disposition;
  final SyncTask? task;

  const SyncTaskFailureResult(this.disposition, this.task);
}

bool isCloudSchemaNotReadyError(Object error) {
  final errorText = error.toString().toLowerCase();
  return errorText.contains('pgrst205') ||
      errorText.contains('pgrst204') ||
      errorText.contains('42p01') ||
      errorText.contains('42703') ||
      errorText.contains('schema cache') ||
      errorText.contains('could not find the table') ||
      errorText.contains('could not find the column') ||
      errorText.contains('relation') && errorText.contains('does not exist') ||
      errorText.contains('table') && errorText.contains('does not exist') ||
      errorText.contains('column') && errorText.contains('does not exist');
}

SyncTaskFailureDisposition syncTaskFailureDisposition(
  SyncTask task,
  Object error,
) {
  if (isCloudSchemaNotReadyError(error)) {
    return SyncTaskFailureDisposition.deferForSchema;
  }

  final errorText = error.toString();
  final isBarcodeSchemaError = errorText.contains('PGRST204') ||
      errorText.contains('schema cache') ||
      errorText.contains('productName') ||
      errorText.contains('23502') ||
      errorText.contains('not-null constraint');
  if ((task.collection == 'barcode_history' && isBarcodeSchemaError) ||
      task.retryCount + 1 >= 5) {
    return SyncTaskFailureDisposition.discard;
  }
  return SyncTaskFailureDisposition.retry;
}

SyncTaskFailureResult syncTaskFailureResult(
  SyncTask task,
  Object error, {
  required DateTime now,
}) {
  final disposition = syncTaskFailureDisposition(task, error);
  switch (disposition) {
    case SyncTaskFailureDisposition.deferForSchema:
      return SyncTaskFailureResult(
        disposition,
        task.deferAfterSchemaError(
          error.toString(),
          now.add(const Duration(minutes: 15)),
        ),
      );
    case SyncTaskFailureDisposition.retry:
      return SyncTaskFailureResult(
        disposition,
        task.copyWith(
          retryCount: task.retryCount + 1,
          lastError: error.toString(),
        ),
      );
    case SyncTaskFailureDisposition.discard:
      return SyncTaskFailureResult(disposition, null);
  }
}
