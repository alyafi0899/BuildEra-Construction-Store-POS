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
    final collections = ['products', 'transactions', 'customers', 'debts', 'debt_payments', 'settings', 'sync_queue'];
    for (final col in collections) {
      if (await Hive.boxExists(_boxName(uid, col))) {
        final box = await Hive.openBox(_boxName(uid, col));
        await box.clear();
        await box.close();
      }
    }
  }
}
