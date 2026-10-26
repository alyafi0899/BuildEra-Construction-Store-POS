import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/sync/services/local_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/print_profile.dart';

final printProfilesProvider = NotifierProvider<PrintProfilesNotifier, List<PrintProfile>>(PrintProfilesNotifier.new);

class PrintProfilesNotifier extends Notifier<List<PrintProfile>> {
  String? _uid;

  @override
  List<PrintProfile> build() {
    _uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
    if (_uid != null) {
      _loadProfiles();
    }
    return [];
  }

  Future<Box> _getBox() => LocalDatabase.openBox(_uid!, 'print_profiles');

  Future<void> _loadProfiles() async {
    final box = await _getBox();
    final list = box.values.map((e) => PrintProfile.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    state = list;
  }

  Future<void> saveProfile(PrintProfile profile) async {
    if (_uid == null) return;
    final box = await _getBox();
    
    String id = profile.id;
    if (id.isEmpty) {
      id = const Uuid().v4();
    }
    
    final newProfile = PrintProfile(
      id: id,
      name: profile.name,
      paperWidth: profile.paperWidth,
      paperHeight: profile.paperHeight,
      labelWidth: profile.labelWidth,
      labelHeight: profile.labelHeight,
      barcodeHeight: profile.barcodeHeight,
      paperMargin: profile.paperMargin,
      labelMargin: profile.labelMargin,
      labelPadding: profile.labelPadding,
      columnCount: profile.columnCount,
      fontSizeName: profile.fontSizeName,
      fontSizeBarcode: profile.fontSizeBarcode,
      fontSizePrice: profile.fontSizePrice,
    );

    await box.put(id, newProfile.toMap());
    _loadProfiles();
  }

  Future<void> deleteProfile(String id) async {
    if (_uid == null) return;
    final box = await _getBox();
    await box.delete(id);
    _loadProfiles();
  }
}
