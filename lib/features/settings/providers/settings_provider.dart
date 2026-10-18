import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/utils/trusted_time_helper.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<StoreSettings> {
  String? _initializedUid;
  String? _settingsChannelUid;
  RealtimeChannel? _settingsChannel;

  @override
  StoreSettings build() {
    final user = ref.watch(authStateProvider).value;
    if (user != null && _initializedUid != user.uid) {
      _initializedUid = user.uid;
      Future.microtask(() {
        _listenForRemoteSettings(user.uid);
        _loadSettings(user.uid);
      });
      return const StoreSettings(isLoading: true);
    } else if (user == null) {
      _initializedUid = null;
      _settingsChannel?.unsubscribe();
      _settingsChannel = null;
      _settingsChannelUid = null;
    }
    ref.onDispose(() => _settingsChannel?.unsubscribe());
    return const StoreSettings();
  }

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  void _listenForRemoteSettings(String uid) {
    if (_settingsChannelUid == uid) return;
    _settingsChannel?.unsubscribe();
    _settingsChannelUid = uid;
    _settingsChannel = _supabase
        .channel('store_settings:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty || _initializedUid != uid) return;
            unawaited(_applyRemoteSettings(uid, payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> _applyRemoteSettings(
      String uid, Map<String, dynamic> remoteRow) async {
    final merged = Map<String, dynamic>.from(state.toMap())
      ..addAll(LocalDatabase.sanitize(remoteRow));
    // Brand images are device-local and must not be overwritten by remote rows.
    merged['logo_url'] = state.logoUrl;
    merged['qris_image_path'] = state.qrisImagePath;
    final settings = StoreSettings.fromMap(merged, isLoading: false);
    state = settings;
    final box = await _getBox(uid);
    await box.put('store_settings', settings.toMap());
  }



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

  Future<void> refreshFromRemote() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    _initializedUid = user.uid;
    await TrustedTimeHelper.syncFromServer(_supabase, user.uid);
    await _loadSettings(user.uid);
  }

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) throw 'User session not found';

    // 1. Update local Riverpod state IMMEDIATELY
    state = settings.copyWith(isLoading: false);

    // 2. Persist to local Hive Cache IMMEDIATELY
    try {
      final box = await _getBox(targetUid);
      await box.put('store_settings', settings.toMap());
    } catch (e) {
      debugPrint('Hive Settings Cache Error: $e');
    }

    // 3. Persist to Remote (Supabase) - fail-soft on schema/network issues
    try {
      final remoteSettings = settings.toMap()
        ..remove('logo_url')
        ..remove('qris_image_path');
      await _supabase.from('users').upsert({
        'id': targetUid,
        ...remoteSettings,
        'updated_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Supabase Remote Settings Sync Exception: $e');
    }
  }
}
