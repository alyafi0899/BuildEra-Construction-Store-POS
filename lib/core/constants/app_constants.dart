// lib/core/constants/app_constants.dart

class AppConstants {
  static const String appName = 'Adi Jaya Cashier';
  static const String appVersion = '1.0.0';
  static const String storeName = 'Toko Bangunan Adi Jaya';
  static const String storeAddress =
      'Jl. Blangkejeren-Kutacane, Blangkejeren, Gayo Lues, Aceh 24584';
  static const String storePhone = '0812-6544-4988';

  static const double taxRate = 0.11; // 11% PPN
  static const int lowStockThreshold = 10;

  static const List<String> categories = [
    'Alat Tangan',
    'Alat Listrik',
    'Material Bangunan',
    'Pipa & Fitting',
    'Cat & Kimia',
    'Keamanan & APD',
    'Pengencang & Baut',
    'Pengukuran',
    'Lain-lain',
  ];

  static const List<String> baseUnits = [
    'pcs',
    'kg',
    'meter',
    'liter',
    'roll',
    'sak',
    'box',
    'set',
    'lusin',
    'lembar',
  ];

  static const List<String> paymentMethods = [
    'Tunai',
    'Debit/Kredit',
    'QRIS',
    'Transfer Bank',
  ];
}

class AppRoutes {
  static const String cashier = '/cashier';
  static const String products = '/products';
  static const String inventory = '/inventory';
  static const String transactions = '/transactions';
  static const String settings = '/settings';
}
