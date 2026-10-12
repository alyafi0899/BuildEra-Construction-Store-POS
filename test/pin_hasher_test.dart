import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/utils/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('hash lalu verify berhasil, PIN salah gagal', () {
      final h = PinHasher.hash('1234');
      expect(PinHasher.isHashed(h), isTrue);
      expect(h.contains('1234'), isFalse);
      expect(PinHasher.verify('1234', h), isTrue);
      expect(PinHasher.verify('1235', h), isFalse);
    });

    test('salt acak: hash PIN yang sama berbeda', () {
      expect(PinHasher.hash('1234'), isNot(PinHasher.hash('1234')));
    });

    test('panjang PIN terbaca dari hash', () {
      expect(PinHasher.lengthOf(PinHasher.hash('123456')), 6);
      expect(PinHasher.lengthOf(PinHasher.hash('1234')), 4);
    });

    test('PIN lama plaintext tetap terverifikasi (sebelum dimigrasi)', () {
      expect(PinHasher.isHashed('1234'), isFalse);
      expect(PinHasher.verify('1234', '1234'), isTrue);
      expect(PinHasher.verify('0000', '1234'), isFalse);
      expect(PinHasher.lengthOf('1234'), 4);
    });

    test('nilai kosong/rusak tidak pernah lolos', () {
      expect(PinHasher.verify('1234', null), isFalse);
      expect(PinHasher.verify('1234', ''), isFalse);
      expect(PinHasher.verify('1234', r'v1$4$bad'), isFalse);
    });
  });
}
