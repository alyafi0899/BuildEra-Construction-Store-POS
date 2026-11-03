import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildera/features/auth/models/store_admin.dart';
import 'package:buildera/features/auth/providers/active_cashier_provider.dart';
import 'package:buildera/core/security/pin_hasher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tahap 2: ActiveCashierNotifier & Permissions Tests', () {
    test('Default inactive state initializes with Owner profile name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(activeCashierProvider);
      expect(state.isSessionActive, isFalse);
      expect(state.isOwner, isTrue);
      expect(state.canEditPrice, isTrue);
      expect(state.canGiveDiscount, isTrue);
      expect(state.canVoid, isTrue);
    });

    test('verifyAndStartSession verifies StoreAdmin PIN correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hashedPin = await PinHasher.hashPin('123456');
      final admin = StoreAdmin(
        id: 'admin-101',
        userId: 'user-1',
        name: 'Siti Kasir',
        pinHash: hashedPin.hash,
        pinSalt: hashedPin.salt,
        pinIterations: hashedPin.iterations,
        canEditPrice: false,
        canGiveDiscount: true,
        canVoid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notifier = container.read(activeCashierProvider.notifier);

      // Verify with wrong PIN throws exception
      expect(
        () => notifier.verifyAndStartSession(admin: admin, pin: '000000'),
        throwsA(contains('PIN Kasir "Siti Kasir" salah')),
      );

      // Verify with correct PIN starts session
      final success = await notifier.verifyAndStartSession(admin: admin, pin: '123456');
      expect(success, isTrue);

      final activeState = container.read(activeCashierProvider);
      expect(activeState.isSessionActive, isTrue);
      expect(activeState.id, equals('admin-101'));
      expect(activeState.name, equals('Siti Kasir'));
      expect(activeState.canEditPrice, isFalse);
      expect(activeState.canGiveDiscount, isTrue);
      expect(activeState.canVoid, isFalse);
    });

    test('5 consecutive wrong attempts triggers lockout', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hashedPin = await PinHasher.hashPin('111111');
      final admin = StoreAdmin(
        id: 'admin-lock-test',
        userId: 'user-1',
        name: 'Andi Kasir',
        pinHash: hashedPin.hash,
        pinSalt: hashedPin.salt,
        pinIterations: hashedPin.iterations,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notifier = container.read(activeCashierProvider.notifier);

      // 4 wrong attempts
      for (var i = 0; i < 4; i++) {
        try {
          await notifier.verifyAndStartSession(admin: admin, pin: '999999');
        } catch (_) {}
      }

      // 5th wrong attempt triggers lockout
      try {
        await notifier.verifyAndStartSession(admin: admin, pin: '999999');
      } catch (_) {}

      // 6th attempt (even with correct PIN) throws lockout error
      expect(
        () => notifier.verifyAndStartSession(admin: admin, pin: '111111'),
        throwsA(contains('terkunci sementara')),
      );
    });

    test('endSession resets active cashier to inactive owner', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hashedPin = await PinHasher.hashPin('123456');
      final admin = StoreAdmin(
        id: 'admin-202',
        userId: 'user-1',
        name: 'Dewi Kasir',
        pinHash: hashedPin.hash,
        pinSalt: hashedPin.salt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notifier = container.read(activeCashierProvider.notifier);
      await notifier.verifyAndStartSession(admin: admin, pin: '123456');

      expect(container.read(activeCashierProvider).isSessionActive, isTrue);

      notifier.endSession();

      final state = container.read(activeCashierProvider);
      expect(state.isSessionActive, isFalse);
      expect(state.isOwner, isTrue);
    });
  });
}
