import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;
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

    // 2. Load from Supabase in background or if no cache
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      
      if (response != null) {
        final data = LocalDatabase.sanitize(Map<String, dynamic>.from(response as Map));
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
      // If offline, ensure we have a working state even if fetch fails
      final user = ref.read(authStateProvider).value;
      if (user != null && state.loginEmail == null) {
        state = state.copyWith(loginEmail: user.email);
      }
    }
  }

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) return;
    
    // Save to Supabase (upsert)
    final data = settings.toMap();
    data['id'] = targetUid; // Set primary key
    
    // Explicitly handle null/empty PIN in the database payload
    if (settings.securityPin == null || settings.securityPin!.isEmpty) {
      data['securityPin'] = null;
    }

    await _client.from('profiles').upsert(data);
    
    // Save to Hive
    final box = await _getBox(targetUid);
    await box.put('store_settings', data);

    state = settings;
  }
}
