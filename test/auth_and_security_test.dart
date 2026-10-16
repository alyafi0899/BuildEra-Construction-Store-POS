import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/features/auth/models/auth_user.dart';
import 'package:buildera/features/settings/models/store_settings.dart';
import 'package:buildera/core/sync/providers/initial_sync_provider.dart';
import 'package:buildera/features/subscription/models/subscription.dart';
import 'package:buildera/shared/models/product.dart';
import 'package:buildera/core/providers/feature_tour_provider.dart';

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

    test('StoreSettings all 8 feature toggles cloud sync map mapping', () {
      final remoteRow = {
        'enable_cashier': false,
        'enable_products': true,
        'enable_purchase': false,
        'enable_transactions': true,
        'enable_debts': false,
        'enable_bills': true,
        'enable_barcode': false,
        'enable_analytics': false,
      };

      final settings = StoreSettings.fromMap(remoteRow);
      expect(settings.enableCashier, isFalse);
      expect(settings.enableProducts, isTrue);
      expect(settings.enablePurchase, isFalse);
      expect(settings.enableTransactions, isTrue);
      expect(settings.enableDebts, isFalse);
      expect(settings.enableBills, isTrue);
      expect(settings.enableBarcode, isFalse);
      expect(settings.enableAnalytics, isFalse);

      final exported = settings.toMap();
      expect(exported['enable_cashier'], isFalse);
      expect(exported['enable_products'], isTrue);
      expect(exported['enable_purchase'], isFalse);
      expect(exported['enable_transactions'], isTrue);
      expect(exported['enable_debts'], isFalse);
      expect(exported['enable_bills'], isTrue);
      expect(exported['enable_barcode'], isFalse);
      expect(exported['enable_analytics'], isFalse);
    });

    test('InitialSyncState defaults for newly registered accounts', () {
      final initialSyncState = InitialSyncState(
        isInitialSyncDone: false,
        isSyncing: false,
        error: null,
      );

      expect(initialSyncState.isInitialSyncDone, isFalse);
      expect(initialSyncState.isSyncing, isFalse);
      expect(initialSyncState.error, isNull);

      final updatedState = initialSyncState.copyWith(
        isInitialSyncDone: true,
        currentTask: 'Selesai',
      );

      expect(updatedState.isInitialSyncDone, isTrue);
      expect(updatedState.currentTask, equals('Selesai'));
    });

    test('Subscription model returns isPremium true when isBypassed is true', () {
      final sub = Subscription(
        userId: 'user-bypass-1',
        planType: PlanType.free,
        status: SubscriptionStatus.none,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isBypassed: true,
      );

      expect(sub.isBypassed, isTrue);
      expect(sub.isPremium, isTrue);
      expect(sub.isNearExpiry, isFalse);
    });

    test('Subscription.fromMap safely parses null timestamps and string bypass flags', () {
      final map = {
        'user_id': 'user-null-ts',
        'plan_type': 'yearly',
        'status': 'active',
        'created_at': null,
        'updated_at': null,
        'is_bypassed': 'true',
      };

      final sub = Subscription.fromMap(map);
      expect(sub.userId, equals('user-null-ts'));
      expect(sub.planType, equals(PlanType.yearly));
      expect(sub.status, equals(SubscriptionStatus.active));
      expect(sub.isBypassed, isTrue);
      expect(sub.isPremium, isTrue);
      expect(sub.createdAt, isA<DateTime>());
      expect(sub.updatedAt, isA<DateTime>());
    });

    test('Product model toMap exports units and financial fields for local DB and cloud sanitization', () {
      final now = DateTime.now();
      final p = Product(
        id: 'prod-sku-1',
        name: 'Semen Gresik 50kg',
        category: 'Semen',
        barcode: '8991234567890',
        costPrice: 55000,
        basePrice: 65000,
        baseUnit: 'sak',
        stock: 100,
        createdAt: now,
        updatedAt: now,
        units: const [
          ProductUnit(
            id: 'unit-1',
            productId: 'prod-sku-1',
            unitName: 'sak',
            conversionRate: 1,
            sellPrice: 65000,
          ),
        ],
      );

      final map = p.toMap();
      expect(map['id'], equals('prod-sku-1'));
      expect(map['barcode'], equals('8991234567890'));
      expect(map['units'], isA<List>());

      // Test payload sanitization: units should be extracted for product_units child table
      final units = map.remove('units') as List;
      expect(units.length, equals(1));
      expect(map.containsKey('units'), isFalse);
    });

    test('FeatureTourState default state and copyWith behavior', () {
      const state = FeatureTourState();
      expect(state.isLanguageSelected, isFalse);
      expect(state.tourCashierDone, isFalse);
      expect(state.isAllSkipped, isFalse);

      final updated = state.copyWith(tourCashierDone: true, isLanguageSelected: true);
      expect(updated.tourCashierDone, isTrue);
      expect(updated.isLanguageSelected, isTrue);
      expect(updated.tourProductsDone, isFalse);
    });
  });
}
