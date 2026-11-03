import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/security/pin_hasher.dart';
import 'package:buildera/features/auth/models/store_admin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 1: PinHasher Tests', () {
    test('generateSalt returns hex string of expected length', () {
      final salt1 = PinHasher.generateSalt();
      final salt2 = PinHasher.generateSalt();

      expect(salt1.length, equals(32)); // 16 bytes = 32 hex chars
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2)));
    });

    test('Different salts produce different hashes for same PIN', () async {
      const pin = '123456';
      final res1 = await PinHasher.hashPin(pin);
      final res2 = await PinHasher.hashPin(pin);

      expect(res1.hash, isNot(equals(res2.hash)));
      expect(res1.salt, isNot(equals(res2.salt)));
      expect(res1.iterations, equals(20000));
    });

    test('verifyPin accepts correct PIN and rejects incorrect PIN', () async {
      const correctPin = '987654';
      const wrongPin = '123456';

      final hashed = await PinHasher.hashPin(correctPin);

      final isCorrectValid = await PinHasher.verifyPin(
        pin: correctPin,
        storedHash: hashed.hash,
        storedSalt: hashed.salt,
        iterations: hashed.iterations,
      );

      final isWrongValid = await PinHasher.verifyPin(
        pin: wrongPin,
        storedHash: hashed.hash,
        storedSalt: hashed.salt,
        iterations: hashed.iterations,
      );

      expect(isCorrectValid, isTrue);
      expect(isWrongValid, isFalse);
    });

    test('constantTimeCompare performs secure comparison', () {
      expect(PinHasher.constantTimeCompare('abc123hash', 'abc123hash'), isTrue);
      expect(PinHasher.constantTimeCompare('abc123hash', 'abc123different'), isFalse);
      expect(PinHasher.constantTimeCompare('short', 'longerstring'), isFalse);
    });
  });

  group('Tahap 1: StoreAdmin Model Tests', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final now = DateTime.now();
      final admin = StoreAdmin(
        id: 'admin-1',
        userId: 'user-100',
        name: 'Budi Kasir',
        pinHash: 'a1b2c3hash',
        pinSalt: 'salt123',
        pinIterations: 20000,
        role: 'cashier',
        isActive: true,
        canEditPrice: false,
        canGiveDiscount: true,
        canVoid: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = admin.toMap();
      expect(map['id'], equals('admin-1'));
      expect(map['user_id'], equals('user-100'));
      expect(map['name'], equals('Budi Kasir'));
      expect(map['pin_hash'], equals('a1b2c3hash'));
      expect(map['is_active'], isTrue);
      expect(map['can_edit_price'], isFalse);

      final restored = StoreAdmin.fromMap(map);
      expect(restored.id, equals(admin.id));
      expect(restored.name, equals(admin.name));
      expect(restored.pinHash, equals(admin.pinHash));
      expect(restored.canEditPrice, isFalse);
      expect(restored.canGiveDiscount, isTrue);
      expect(restored.canVoid, isFalse);
    });

    test('StoreAdmin copyWith updates specific fields correctly', () {
      final admin = StoreAdmin(
        id: 'admin-1',
        userId: 'user-100',
        name: 'Budi Kasir',
        pinHash: 'hash1',
        pinSalt: 'salt1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final deactivated = admin.copyWith(isActive: false, name: 'Budi (Nonaktif)');
      expect(deactivated.id, equals('admin-1'));
      expect(deactivated.isActive, isFalse);
      expect(deactivated.name, equals('Budi (Nonaktif)'));
      expect(deactivated.pinHash, equals('hash1')); // Original hash retained
    });
  });
}
