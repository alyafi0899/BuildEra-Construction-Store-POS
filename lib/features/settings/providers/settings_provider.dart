import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';
import '../../../core/sync/services/local_database.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<StoreSettings> {
  @override
  StoreSettings build() {
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      _loadSettings(user.uid);
    }
    return const StoreSettings();
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  Future<void> _loadSettings(String uid) async {
    // 1. Try to load from Hive first (Instant)
    final box = await _getBox(uid);
    final cached = box.get('store_settings');
    if (cached != null) {
      state = StoreSettings.fromMap(Map<String, dynamic>.from(cached as Map));
    }

    // 2. Load from Firestore in background or if no cache
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final settings = StoreSettings.fromMap(doc.data() as Map<String, dynamic>);
        state = settings;
        // Update cache
        await box.put('store_settings', settings.toMap());
      }
    } catch (e) {
      // If offline, we stay with cached state
    }
  }

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) return;
    
    // Save to Firestore
    await _db.collection('users').doc(targetUid).set(settings.toMap(), SetOptions(merge: true));
    
    // Save to Hive
    final box = await _getBox(targetUid);
    await box.put('store_settings', settings.toMap());

    state = settings;
  }
}
