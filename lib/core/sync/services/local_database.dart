import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class LocalDatabase {
  static final Set<String> _migratedBoxes = {};

  static Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      // On Desktop/Mobile, we will manage paths per user
      await Hive.initFlutter(); 
    }
  }

  static Future<String> _getDatabasePath(String uid) async {
    final baseDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(baseDir.path, 'BuildEra_Offline', uid, 'databases'));
    
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return dbDir.path;
  }

  static String _boxName(String uid, String collection) => '${collection}_$uid';

  static Future<Box<T>> openBox<T>(String uid, String collection) async {
    if (kIsWeb) {
      return await Hive.openBox<T>(_boxName(uid, collection));
    }

    final dbPath = await _getDatabasePath(uid);
    final boxName = _boxName(uid, collection);

    // Migration logic
    if (!_migratedBoxes.contains(boxName)) {
      await _migrateIfNecessary(uid, collection, dbPath);
      _migratedBoxes.add(boxName);
    }

    return await Hive.openBox<T>(boxName, path: dbPath);
  }

  static Future<void> _migrateIfNecessary(String uid, String collection, String newPath) async {
    try {
      final boxName = _boxName(uid, collection);
      final docDir = await getApplicationDocumentsDirectory();
      
      final oldHiveFile = File(p.join(docDir.path, '$boxName.hive'));
      final oldLockFile = File(p.join(docDir.path, '$boxName.lock'));

      if (await oldHiveFile.exists()) {
        debugPrint('MIGRATION: Found legacy database file for $collection in Documents. Moving...');
        
        final newHiveFile = File(p.join(newPath, '$boxName.hive'));
        final newLockFile = File(p.join(newPath, '$boxName.lock'));

        // Copy hive file
        await oldHiveFile.copy(newHiveFile.path);
        
        // Copy lock file if exists
        if (await oldLockFile.exists()) {
          await oldLockFile.copy(newLockFile.path);
        }

        // Delete old files
        await oldHiveFile.delete();
        if (await oldLockFile.exists()) {
          await oldLockFile.delete();
        }
        
        debugPrint('MIGRATION: Successfully moved $collection to $newPath');
      }
    } catch (e) {
      debugPrint('MIGRATION ERROR for $collection: $e');
    }
  }

  static Future<void> clearUserCache(String uid) async {
    final collections = ['products', 'transactions', 'customers', 'debts', 'debt_payments', 'settings', 'sync_queue', 'suppliers', 'shipping_services', 'restock_history', 'metadata', 'print_profiles', 'sync_meta', 'barcode_history'];
    
    final dbPath = kIsWeb ? null : await _getDatabasePath(uid);

    for (final col in collections) {
      final name = _boxName(uid, col);
      if (await Hive.boxExists(name, path: dbPath)) {
        final box = await Hive.openBox(name, path: dbPath);
        await box.clear();
        await box.close();
      }
    }
  }

  static Future<void> setMetadata(String uid, String key, dynamic value) async {
    final box = await openBox(uid, 'metadata');
    await box.put(key, value);
  }

  static Future<dynamic> getMetadata(String uid, String key) async {
    final box = await openBox(uid, 'metadata');
    return box.get(key);
  }

  /// Recursively converts Firestore Timestamps to ISO-8601 strings
  /// so they can be saved in Hive without custom adapters.
  static Map<String, dynamic> sanitize(Map<String, dynamic> data) {
    return sanitizeMap(data);
  }
}

/// Top-level functions for Isolate compatibility
Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
  final sanitized = <String, dynamic>{};
  data.forEach((key, value) {
    sanitized[key] = sanitizeValue(value);
  });
  return sanitized;
}

dynamic sanitizeValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  } else if (value is Map) {
    return sanitizeMap(Map<String, dynamic>.from(value));
  } else if (value is List) {
    return value.map(sanitizeValue).toList();
  }
  return value;
}
