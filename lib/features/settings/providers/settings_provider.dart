import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';

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

  Future<void> _loadSettings(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      state = StoreSettings.fromMap(doc.data() as Map<String, dynamic>);
    }
  }

  Future<void> updateSettings(StoreSettings settings) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
    await _db.collection('users').doc(user.uid).set(settings.toMap(), SetOptions(merge: true));
    state = settings;
  }
}
