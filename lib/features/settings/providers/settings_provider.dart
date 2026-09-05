import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';
import '../../../core/sync/services/local_database.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<StoreSettings> {
  bool _isInitialized = false;

  @override
  StoreSettings build() {
    final user = ref.watch(authStateProvider).value;
    if (user != null && !_isInitialized) {
      _isInitialized = true;
      Future.microtask(() => _loadSettings(user.uid));
      return const StoreSettings(isLoading: true);
    } else if (user == null) {
      _isInitialized = false;
    }
    return const StoreSettings();
  }

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  Future<void> _loadSettings(String uid) async {
    // 1. Instant load from Hive
    try {
      final box = await _getBox(uid);
      final cached = box.get('store_settings');
      if (cached != null) {
        state = StoreSettings.fromMap(
          Map<String, dynamic>.from(cached as Map),
          isLoading: true, // Still "loading" until Supabase confirms or fails
        );
      }
    } catch (e) {
      debugPrint('Hive Load Error: $e');
    }

    // 2. Background load from Supabase with retry logic
    int retries = 3;
    while (retries > 0) {
      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
            
        if (response != null) {
          final data = LocalDatabase.sanitize(response);
          final settings = StoreSettings.fromMap(data, isLoading: false);
          state = settings;
          
          final box = await _getBox(uid);
          await box.put('store_settings', settings.toMap());
          return; 
        } else {
          // New user (no remote settings)
          final user = ref.read(authStateProvider).value;
          state = state.copyWith(
            loginEmail: user?.email,
            isLoading: false,
          );
          return;
        }
      } catch (e) {
        retries--;
        if (retries == 0) {
          debugPrint('Supabase Settings Fatal Error: $e');
          // If we have Hive data, just mark loading as done. 
          // If not, it's a blank fresh state.
          state = state.copyWith(isLoading: false);
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) throw 'User session not found';
    
    try {
      // Update local state IMMEDIATELY so UI can react (e.g. AuthGate)
      state = settings.copyWith(isLoading: false);

      // 1. Persist to Remote
      await _supabase.from('users').upsert({
        'id': targetUid,
        ...settings.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));
      
      // 2. Persist to Hive Cache
      final box = await _getBox(targetUid);
      await box.put('store_settings', settings.toMap());

    } catch (e) {
      debugPrint('Update Settings Error: $e');
      // Update Hive anyway for offline consistency
      final box = await _getBox(targetUid);
      await box.put('store_settings', settings.toMap());
      rethrow;
    }
  }
}
