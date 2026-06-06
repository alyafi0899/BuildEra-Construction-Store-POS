import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_settings.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<StoreSettings> {
  final _db = FirebaseFirestore.instance;
  static const _docPath = 'settings/store';

  @override
  StoreSettings build() {
    _listenToSettings();
    return const StoreSettings();
  }

  void _listenToSettings() {
    _db.doc(_docPath).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        state = StoreSettings.fromMap(snapshot.data()!);
      }
    }, onError: (e) {
      // Handle error
    });
  }

  Future<void> updateSettings(StoreSettings settings) async {
    try {
      await _db.doc(_docPath).set(settings.toMap(), SetOptions(merge: true));
      // State will be updated by the listener
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> updateLogo(String? logoUrl) async {
    final updated = state.copyWith(logoUrl: logoUrl);
    await updateSettings(updated);
  }
}
