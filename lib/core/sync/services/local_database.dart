import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  static String _boxName(String uid, String collection) => '${collection}_$uid';

  static Future<Box<T>> openBox<T>(String uid, String collection) async {
    return await Hive.openBox<T>(_boxName(uid, collection));
  }

  static Future<void> clearUserCache(String uid) async {
    final collections = ['products', 'transactions', 'customers', 'debts', 'debt_payments', 'settings', 'sync_queue', 'suppliers', 'shipping_services', 'restock_history'];
    for (final col in collections) {
      if (await Hive.boxExists(_boxName(uid, col))) {
        final box = await Hive.openBox(_boxName(uid, col));
        await box.clear();
        await box.close();
      }
    }
  }

  /// Recursively converts Firestore Timestamps to ISO-8601 strings
  /// so they can be saved in Hive without custom adapters.
  static Map<String, dynamic> sanitize(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      sanitized[key] = _sanitizeValue(value);
    });
    return sanitized;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return sanitize(Map<String, dynamic>.from(value));
    } else if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }
}
