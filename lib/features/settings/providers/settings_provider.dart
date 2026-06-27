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

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) return;
    
    await _db.collection('users').doc(targetUid).set(settings.toMap(), SetOptions(merge: true));
    state = settings;
  }
}
