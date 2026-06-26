import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../models/shipping_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';

final _uuid = const Uuid();

// ── Repository ─────────────────────────────────────────────────────────────

class EntityRepository {
  final String _uid;
  final Ref _ref;

  EntityRepository(this._uid, this._ref);

  Future<Box> _getBox(String col) => LocalDatabase.openBox(_uid, col);

  // ── Suppliers ────────────────────────────────────────────────────────────

  Stream<List<Supplier>> getSuppliersStream() async* {
    final box = await _getBox('suppliers');
    yield _suppliersFromBox(box);
    yield* box.watch().map((_) => _suppliersFromBox(box));
  }

  List<Supplier> _suppliersFromBox(Box box) {
    final list = box.values.map((d) => Supplier.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> saveSupplier(Supplier s) async {
    final box = await _getBox('suppliers');
    final data = s.toMap();
    await box.put(s.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'suppliers',
      documentId: s.id,
      action:     SyncAction.update,
      data:       data,
    );
  }

  Future<void> deleteSupplier(String id) async {
    final box = await _getBox('suppliers');
    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'suppliers',
      documentId: id,
      action:     SyncAction.delete,
      data:       {},
    );
  }

  // ── Shipping Services ───────────────────────────────────────────────────

  Stream<List<ShippingService>> getShippingServicesStream() async* {
    final box = await _getBox('shipping_services');
    yield _shippingFromBox(box);
    yield* box.watch().map((_) => _shippingFromBox(box));
  }

  List<ShippingService> _shippingFromBox(Box box) {
    final list = box.values.map((d) => ShippingService.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> saveShippingService(ShippingService s) async {
    final box = await _getBox('shipping_services');
    final data = s.toMap();
    await box.put(s.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'shipping_services',
      documentId: s.id,
      action:     SyncAction.update,
      data:       data,
    );
  }

  Future<void> deleteShippingService(String id) async {
    final box = await _getBox('shipping_services');
    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'shipping_services',
      documentId: id,
      action:     SyncAction.delete,
      data:       {},
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final entityRepositoryProvider = Provider<EntityRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return EntityRepository(user?.uid ?? 'unknown', ref);
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(entityRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getSuppliersStream();
});

final shippingServicesProvider = StreamProvider<List<ShippingService>>((ref) {
  final repo = ref.watch(entityRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getShippingServicesStream();
});
