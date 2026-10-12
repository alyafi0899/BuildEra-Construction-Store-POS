import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/features/auth/models/auth_user.dart';
import 'package:buildera/features/settings/models/store_settings.dart';

void main() {
  group('Auth & Security Model Tests', () {
    test('AuthUser should instantiate correctly', () {
      const user = AuthUser(
        uid: 'user-123',
        email: 'admin@buildera.com',
        isEmailVerified: true,
        displayName: 'Store Manager',
      );

      expect(user.uid, equals('user-123'));
      expect(user.email, equals('admin@buildera.com'));
      expect(user.isEmailVerified, isTrue);
      expect(user.displayName, equals('Store Manager'));
    });

    test('StoreSettings security PIN setup and page locking validation', () {
      const settings = StoreSettings(
        businessName: 'Toko Bangunan Jaya',
        ownerName: 'Budi Santoso',
        phone: '08123456789',
        address: 'Jl. Utama No. 10',
        securityPin: '123456',
        lockAnalyticsPage: true,
        lockProductsPage: true,
        lockInventoryPage: true,
      );

      expect(settings.businessName, equals('Toko Bangunan Jaya'));
      expect(settings.securityPin, equals('123456'));
      expect(settings.securityPin!.length, equals(6));
      expect(settings.lockAnalyticsPage, isTrue);

      final map = settings.toMap();
      expect(map['business_name'], equals('Toko Bangunan Jaya'));
      expect(map['security_pin'], equals('123456'));

      final restoredSettings = StoreSettings.fromMap(map);
      expect(restoredSettings.businessName, equals('Toko Bangunan Jaya'));
      expect(restoredSettings.securityPin, equals('123456'));
      expect(restoredSettings.lockAnalyticsPage, isTrue);
    });

    test('StoreSettings security PIN default null or empty', () {
      const defaultSettings = StoreSettings();
      expect(defaultSettings.securityPin, isNull);
      expect(defaultSettings.businessName, isEmpty);
    });

    test('StoreSettings feature toggle copyWith and map serialization', () {
      const settings = StoreSettings(
        securityPin: '888888',
        enableCashier: true,
        enableAnalytics: true,
        enablePurchase: false,
      );

      final toggled = settings.copyWith(enablePurchase: true, enableAnalytics: false);
      expect(toggled.enablePurchase, isTrue);
      expect(toggled.enableAnalytics, isFalse);
      expect(toggled.securityPin, equals('888888'));

      final map = toggled.toMap();
      expect(map['enable_purchase'], isTrue);
      expect(map['enable_analytics'], isFalse);

      final restored = StoreSettings.fromMap(map);
      expect(restored.enablePurchase, isTrue);
      expect(restored.enableAnalytics, isFalse);
    });
  });
}
