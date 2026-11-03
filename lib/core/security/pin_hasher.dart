import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PinHashResult {
  final String hash;
  final String salt;
  final int iterations;

  const PinHashResult({
    required this.hash,
    required this.salt,
    required this.iterations,
  });
}

class PinHasher {
  static const int defaultIterations = 20000;
  static const int saltBytes = 16;

  /// Generates a cryptographically secure random salt hex string
  static String generateSalt([int length = saltBytes]) {
    final rng = Random.secure();
    final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Synchronous PBKDF2 HMAC-SHA256 calculation
  static String pbkdf2HmacSha256({
    required String pin,
    required String saltHex,
    int iterations = defaultIterations,
  }) {
    final saltBytes = _hexToBytes(saltHex);
    final pinBytes = utf8.encode(pin);

    // Initial HMAC pass with salt + 0x00000001
    final hmac = Hmac(sha256, pinBytes);
    var u = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a PIN in an isolate using compute()
  static Future<PinHashResult> hashPin(
    String pin, {
    String? salt,
    int iterations = defaultIterations,
  }) async {
    final effectiveSalt = salt ?? generateSalt();
    final hashHex = await compute(
      _hashPinIsolate,
      _PinHashArgs(pin: pin, salt: effectiveSalt, iterations: iterations),
    );
    return PinHashResult(
      hash: hashHex,
      salt: effectiveSalt,
      iterations: iterations,
    );
  }

  /// Verifies a PIN against stored hash, salt, and iterations in constant-time
  static Future<bool> verifyPin({
    required String pin,
    required String storedHash,
    required String storedSalt,
    int iterations = defaultIterations,
  }) async {
    final computedHash = await compute(
      _hashPinIsolate,
      _PinHashArgs(pin: pin, salt: storedSalt, iterations: iterations),
    );
    return constantTimeCompare(computedHash, storedHash);
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool constantTimeCompare(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);

    if (aBytes.length != bBytes.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < aBytes.length; i++) {
      result |= aBytes[i] ^ bBytes[i];
    }
    return result == 0;
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}

class _PinHashArgs {
  final String pin;
  final String salt;
  final int iterations;

  const _PinHashArgs({
    required this.pin,
    required this.salt,
    required this.iterations,
  });
}

String _hashPinIsolate(_PinHashArgs args) {
  return PinHasher.pbkdf2HmacSha256(
    pin: args.pin,
    saltHex: args.salt,
    iterations: args.iterations,
  );
}
