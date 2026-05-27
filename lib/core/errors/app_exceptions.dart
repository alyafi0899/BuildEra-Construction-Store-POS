// lib/core/errors/app_exceptions.dart

class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message) : super(code: 'DB_ERROR');
}

class ValidationException extends AppException {
  const ValidationException(super.message) : super(code: 'VALIDATION_ERROR');
}

class StockException extends AppException {
  const StockException(super.message) : super(code: 'STOCK_ERROR');
}

class NotFoundException extends AppException {
  const NotFoundException(super.message) : super(code: 'NOT_FOUND');
}
