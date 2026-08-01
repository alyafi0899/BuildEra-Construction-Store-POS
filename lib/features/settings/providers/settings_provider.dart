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
    try {
      final box = await _getBox(uid);
      final cached = box.get('store_settings');
      if (cached != null) {
        state = StoreSettings.fromMap(cached as Map);
      }
    } catch (e) {
      // Ignore hive errors
    }

    // 2. Load from Firestore in background or if no cache
    try {
      final doc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 10));
      if (doc.exists) {
        final data = LocalDatabase.sanitize(doc.data()!);
        final settings = StoreSettings.fromMap(data);
        state = settings;
        // Update cache
        try {
          final box = await _getBox(uid);
          await box.put('store_settings', settings.toMap());
        } catch (e) {
          // Ignore hive write errors
        }
      } else {
        // Handle case where user document doesn't exist yet (new registration)
        // Ensure state is at least updated with login email if available
        final user = ref.read(authStateProvider).value;
        if (user != null && state.loginEmail == null) {
          state = state.copyWith(loginEmail: user.email);
        }
      }
    } catch (e) {
      // If offline, ensure we have a working state even if doc fetch fails
      final user = ref.read(authStateProvider).value;
      if (user != null && state.loginEmail == null) {
        state = state.copyWith(loginEmail: user.email);
      }
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
