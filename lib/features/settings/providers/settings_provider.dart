import 'package:supabase_flutter/supabase_flutter.dart';
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

  SupabaseClient get _supabase => ref.watch(supabaseClientProvider);
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  Future<void> _loadSettings(String uid) async {
    // 1. Try to load from Hive first (Instant)
    final box = await _getBox(uid);
    final cached = box.get('store_settings');
    if (cached != null) {
      state = StoreSettings.fromMap(cached as Map);
    }

    // 2. Load from Supabase in background or if no cache
    try {
      final response = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
      if (response != null) {
        final settings = StoreSettings.fromMap(response);
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
    
    // Save to Supabase
    await _supabase.from('profiles').upsert({
      'id': targetUid,
      ...settings.toMap(),
    });
    
    // Save to Hive
    final box = await _getBox(targetUid);
    await box.put('store_settings', settings.toMap());

    state = settings;
  }
}
