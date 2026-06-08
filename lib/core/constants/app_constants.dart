class AppConstants {
  static const String appName = 'KONSTRUKSI POS';
  static const String appVersion = '1.0.0';
  static const String dbName = 'konstruksi_pos.db';
  static const int dbVersion = 1;

  // Units
  static const List<String> baseUnits = ['pcs', 'kg', 'meter', 'liter', 'roll', 'box', 'sack', 'sheet'];

  // Categories
  static const List<String> categories = [
    'Besi & Baja',
    'Semen & Material',
    'Kayu & Triplek',
    'Pipa & Fitting',
    'Cat & Pelapis',
    'Alat Listrik',
    'Alat Tangan',
    'Alat Berat',
    'Tali & Kawat',
    'Paku & Baut',
    'Keramik & Granit',
    'Lainnya',
  ];

  // Tax
  static const double defaultTaxRate = 0.11; // 11% PPN Indonesia

  // Low stock threshold
  static const double lowStockThreshold = 10;

  // Payment methods
  static const String paymentCash     = 'Tunai';
  static const String paymentQris     = 'QRIS';
  static const String paymentDebit    = 'Debit';
  static const String paymentTransfer = 'Transfer Bank';

  static const List<String> paymentMethods = [paymentCash, paymentQris, paymentDebit, paymentTransfer];
}
