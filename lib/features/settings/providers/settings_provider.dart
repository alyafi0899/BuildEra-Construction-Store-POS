import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';
import '../../../core/sync/services/local_database.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<StoreSettings> {
  String? _initializedUid;

  @override
  StoreSettings build() {
    final user = ref.watch(authStateProvider).value;
    if (user != null && _initializedUid != user.uid) {
      _initializedUid = user.uid;
      Future.microtask(() => _loadSettings(user.uid));
      return const StoreSettings(isLoading: true);
    } else if (user == null) {
      _initializedUid = null;
    }
    return const StoreSettings();
  }

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  Future<void> _loadSettings(String uid) async {
    StoreSettings? cachedSettings;

    // 1. Instant load from Hive
    try {
      final box = await _getBox(uid);
      final cached = box.get('store_settings');
      if (cached != null) {
        cachedSettings = StoreSettings.fromMap(
          Map<String, dynamic>.from(cached as Map),
        );
        state = cachedSettings.copyWith(isLoading: true);
      }
    } catch (e) {
      debugPrint('Hive Load Error: $e');
    }

    // 2. Use auth metadata as a recovery source for registration details.
    Map<String, dynamic> metadata = {};
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser?.id == uid) {
        metadata = Map<String, dynamic>.from(authUser!.userMetadata ?? {});
        metadata['login_email'] ??= authUser.email;
      }
    } catch (e) {
      debugPrint('Auth metadata load error: $e');
    }

    // 3. Background load from Supabase with retry logic
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
          final data = Map<String, dynamic>.from(metadata);
          final remoteData = LocalDatabase.sanitize(response);
          for (final entry in remoteData.entries) {
            final value = entry.value;
            if (value != null &&
                (value is! String || value.trim().isNotEmpty)) {
              data[entry.key] = value;
            }
          }

          if (cachedSettings?.logoUrl != null) {
            data['logo_url'] = cachedSettings!.logoUrl;
          }
          if (cachedSettings?.qrisImagePath != null) {
            data['qris_image_path'] = cachedSettings!.qrisImagePath;
          }

          final settings = StoreSettings.fromMap(data, isLoading: false);
          state = settings;

          final box = await _getBox(uid);
          await box.put('store_settings', settings.toMap());
          return;
        } else {
          final settingsMap = Map<String, dynamic>.from(metadata);
          if (cachedSettings?.logoUrl != null) {
            settingsMap['logo_url'] = cachedSettings!.logoUrl;
          }
          if (cachedSettings?.qrisImagePath != null) {
            settingsMap['qris_image_path'] = cachedSettings!.qrisImagePath;
          }

          final settings = StoreSettings.fromMap(settingsMap, isLoading: false);
          state = settings;

          final box = await _getBox(uid);
          await box.put('store_settings', settings.toMap());

          if (metadata.isNotEmpty) {
            final remoteSettings = settings.toMap()
              ..remove('logo_url')
              ..remove('qris_image_path');
            try {
              await _supabase.from('users').upsert({
                'id': uid,
                ...remoteSettings,
                'updated_at': DateTime.now().toIso8601String(),
              }).timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint('Could not seed public.users from auth metadata: $e');
            }
          }
          return;
        }
      } catch (e) {
        retries--;
        if (retries == 0) {
          debugPrint('Supabase Settings Fatal Error: $e');
          final fallbackData = Map<String, dynamic>.from(metadata);
          if (cachedSettings?.logoUrl != null) {
            fallbackData['logo_url'] = cachedSettings!.logoUrl;
          }
          if (cachedSettings?.qrisImagePath != null) {
            fallbackData['qris_image_path'] = cachedSettings!.qrisImagePath;
          }
          final fallback = StoreSettings.fromMap(
            fallbackData,
            isLoading: false,
          );
          state = fallback;
          try {
            final box = await _getBox(uid);
            await box.put('store_settings', fallback.toMap());
          } catch (cacheError) {
            debugPrint('Settings fallback cache error: $cacheError');
          }
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
      final remoteSettings = settings.toMap()
        ..remove('logo_url')
        ..remove('qris_image_path');
      await _supabase.from('users').upsert({
        'id': targetUid,
        ...remoteSettings,
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
