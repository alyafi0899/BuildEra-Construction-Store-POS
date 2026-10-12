import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hash PIN dengan PBKDF2-HMAC-SHA256 + salt acak.
///
/// Format tersimpan: `v1$<panjangPin>$<salt>$<hash>` (base64url).
/// Nilai tanpa awalan `v1$` dianggap PIN lama (plaintext) dan dimigrasi
/// otomatis oleh SettingsNotifier saat settings dimuat.
class PinHasher {
  PinHasher._();

  static const _sep = r'$';
  static const _version = 'v1';
  static const _iterations = 20000;

  static bool isHashed(String? stored) =>
      stored != null && stored.startsWith('$_version$_sep');

  static String hash(String pin, {List<int>? salt}) {
    final rng = Random.secure();
    final s = salt ?? List<int>.generate(16, (_) => rng.nextInt(256));
    final derived = _pbkdf2(utf8.encode(pin), s);
    return [
      _version,
      pin.length.toString(),
      base64Url.encode(s),
      base64Url.encode(derived),
    ].join(_sep);
  }

  static bool verify(String entered, String? stored) {
    if (stored == null || stored.isEmpty) return false;
    if (!isHashed(stored)) return _constantTimeEquals(utf8.encode(entered), utf8.encode(stored));

    final parts = stored.split(_sep);
    if (parts.length != 4) return false;
    try {
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      return _constantTimeEquals(_pbkdf2(utf8.encode(entered), salt), expected);
    } catch (_) {
      return false;
    }
  }

  /// Panjang PIN untuk menggambar kotak input (4 jika tidak diketahui).
  static int? lengthOf(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (!isHashed(stored)) return stored.length;
    final parts = stored.split(_sep);
    return parts.length == 4 ? int.tryParse(parts[1]) : null;
  }

  // PBKDF2 satu blok (output 32 byte = panjang SHA-256).
  static List<int> _pbkdf2(List<int> password, List<int> salt) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
