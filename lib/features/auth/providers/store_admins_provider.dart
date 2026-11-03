import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_admin.dart';
import '../../../core/security/pin_hasher.dart';

final storeAdminsRepositoryProvider = Provider<StoreAdminsRepository>((ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  final client = ref.read(supabaseClientProvider);
  return StoreAdminsRepository(uid ?? 'unknown', client, ref);
});

final storeAdminsProvider = StreamProvider<List<StoreAdmin>>((ref) {
  final repo = ref.watch(storeAdminsRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getAdminsStream();
});

class StoreAdminsRepository {
  final String _uid;
  final SupabaseClient _client;
  final Ref _ref;
  final _uuid = const Uuid();

  StoreAdminsRepository(this._uid, this._client, this._ref);

  SupabaseClient get client => _client;

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'store_admins');

  Stream<List<StoreAdmin>> getAdminsStream() async* {
    if (_uid == 'unknown') {
      yield [];
      return;
    }
    final box = await _getBox();
    yield _readAdminsFromBox(box);

    yield* box.watch().map((_) => _readAdminsFromBox(box));
  }

  List<StoreAdmin> _readAdminsFromBox(Box box) {
    final list = <StoreAdmin>[];
    for (final raw in box.values) {
      if (raw is Map) {
        final data = LocalDatabase.sanitize(Map<String, dynamic>.from(raw));
        list.add(StoreAdmin.fromMap(data));
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<List<StoreAdmin>> getActiveAdmins() async {
    final box = await _getBox();
    final admins = _readAdminsFromBox(box);
    return admins.where((a) => a.isActive).toList();
  }

  Future<void> _validateAdminInput({
    required String name,
    required String pin,
    String? excludeAdminId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw 'Nama admin wajib diisi';
    }

    if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      throw 'PIN harus berupa 4-6 digit angka';
    }

    final settings = _ref.read(settingsProvider);
    if (settings.securityPin != null && settings.securityPin == pin) {
      throw 'PIN admin tidak boleh sama dengan PIN Pemilik Toko';
    }

    final activeAdmins = await getActiveAdmins();
    final duplicate = activeAdmins.any(
      (a) => a.id != excludeAdminId && a.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (duplicate) {
      throw 'Nama admin "$trimmedName" sudah digunakan oleh kasir aktif lain';
    }
  }

  Future<StoreAdmin> addAdmin({
    required String name,
    required String pin,
    bool canEditPrice = true,
    bool canGiveDiscount = true,
    bool canVoid = false,
  }) async {
    if (_uid == 'unknown') throw 'User session not found';

    await _validateAdminInput(name: name, pin: pin);

    final hashed = await PinHasher.hashPin(pin);
    final now = DateTime.now();
    final admin = StoreAdmin(
      id: _uuid.v4(),
      userId: _uid,
      name: name.trim(),
      pinHash: hashed.hash,
      pinSalt: hashed.salt,
      pinIterations: hashed.iterations,
      role: 'cashier',
      isActive: true,
      canEditPrice: canEditPrice,
      canGiveDiscount: canGiveDiscount,
      canVoid: canVoid,
      createdAt: now,
      updatedAt: now,
    );

    final box = await _getBox();
    await box.put(admin.id, admin.toMap());

    unawaited(_ref.read(syncProvider.notifier).addBatchToQueue([
      SyncTask(
        id: _uuid.v4(),
        collection: 'store_admins',
        documentId: admin.id,
        action: SyncAction.create,
        data: admin.toMap(),
        createdAt: now,
      ),
    ]));

    return admin;
  }

  Future<void> updateAdminPermissions({
    required String adminId,
    String? name,
    bool? canEditPrice,
    bool? canGiveDiscount,
    bool? canVoid,
  }) async {
    if (_uid == 'unknown') throw 'User session not found';

    final box = await _getBox();
    final raw = box.get(adminId);
    if (raw == null || raw is! Map) throw 'Data admin tidak ditemukan';

    var admin = StoreAdmin.fromMap(LocalDatabase.sanitize(Map<String, dynamic>.from(raw)));

    if (name != null && name.trim() != admin.name) {
      // Validate name uniqueness among active admins (using existing PIN for validation)
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) throw 'Nama admin wajib diisi';
      final activeAdmins = await getActiveAdmins();
      final duplicate = activeAdmins.any(
        (a) => a.id != adminId && a.name.trim().toLowerCase() == trimmedName.toLowerCase(),
      );
      if (duplicate) throw 'Nama admin "$trimmedName" sudah digunakan oleh kasir aktif lain';
      admin = admin.copyWith(name: trimmedName);
    }

    final now = DateTime.now();
    admin = admin.copyWith(
      canEditPrice: canEditPrice ?? admin.canEditPrice,
      canGiveDiscount: canGiveDiscount ?? admin.canGiveDiscount,
      canVoid: canVoid ?? admin.canVoid,
      updatedAt: now,
    );

    await box.put(admin.id, admin.toMap());

    unawaited(_ref.read(syncProvider.notifier).addBatchToQueue([
      SyncTask(
        id: _uuid.v4(),
        collection: 'store_admins',
        documentId: admin.id,
        action: SyncAction.update,
        data: admin.toMap(),
        createdAt: now,
      ),
    ]));
  }

  Future<void> resetAdminPin({
    required String adminId,
    required String newPin,
  }) async {
    if (_uid == 'unknown') throw 'User session not found';

    final box = await _getBox();
    final raw = box.get(adminId);
    if (raw == null || raw is! Map) throw 'Data admin tidak ditemukan';

    final admin = StoreAdmin.fromMap(LocalDatabase.sanitize(Map<String, dynamic>.from(raw)));
    await _validateAdminInput(name: admin.name, pin: newPin, excludeAdminId: adminId);

    final hashed = await PinHasher.hashPin(newPin);
    final now = DateTime.now();
    final updated = admin.copyWith(
      pinHash: hashed.hash,
      pinSalt: hashed.salt,
      pinIterations: hashed.iterations,
      updatedAt: now,
    );

    await box.put(updated.id, updated.toMap());

    unawaited(_ref.read(syncProvider.notifier).addBatchToQueue([
      SyncTask(
        id: _uuid.v4(),
        collection: 'store_admins',
        documentId: updated.id,
        action: SyncAction.update,
        data: updated.toMap(),
        createdAt: now,
      ),
    ]));
  }

  Future<void> setAdminActive({
    required String adminId,
    required bool isActive,
  }) async {
    if (_uid == 'unknown') throw 'User session not found';

    final box = await _getBox();
    final raw = box.get(adminId);
    if (raw == null || raw is! Map) throw 'Data admin tidak ditemukan';

    var admin = StoreAdmin.fromMap(LocalDatabase.sanitize(Map<String, dynamic>.from(raw)));
    if (isActive && !admin.isActive) {
      // Re-activating: check if name conflicts with another active admin
      final activeAdmins = await getActiveAdmins();
      final duplicate = activeAdmins.any(
        (a) => a.id != adminId && a.name.trim().toLowerCase() == admin.name.trim().toLowerCase(),
      );
      if (duplicate) throw 'Nama admin "${admin.name}" sudah digunakan oleh kasir aktif lain';
    }

    final now = DateTime.now();
    admin = admin.copyWith(isActive: isActive, updatedAt: now);

    await box.put(admin.id, admin.toMap());

    unawaited(_ref.read(syncProvider.notifier).addBatchToQueue([
      SyncTask(
        id: _uuid.v4(),
        collection: 'store_admins',
        documentId: admin.id,
        action: SyncAction.update,
        data: admin.toMap(),
        createdAt: now,
      ),
    ]));
  }
}
