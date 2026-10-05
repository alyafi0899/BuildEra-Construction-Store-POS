import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import '../../../shared/models/purchase.dart';
import '../../products/models/product_financials.dart';
import '../../inventory/models/restock_record.dart';
import '../../inventory/providers/restock_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import 'purchase_cart_provider.dart';

final _uuid = Uuid();

// ── Repository ─────────────────────────────────────────────────────────────

class PurchaseRepository {
  final String _uid;
  final Ref _ref;

  PurchaseRepository(this._uid, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'purchases');

  Future<void> bootstrap({bool force = false}) async {
    final box = await _getBox();
    if (box.isNotEmpty && !force) return;

    final client = _ref.read(supabaseClientProvider);
    final response = await client
        .from('purchases')
        .select()
        .eq('user_id', _uid)
        .timeout(const Duration(seconds: 20));

    final entries = <String, dynamic>{};
    for (final item in response) {
      entries[item['id'] as String] =
          LocalDatabase.sanitize(Map<String, dynamic>.from(item));
    }

    if (force) await box.clear();
    if (entries.isNotEmpty) await box.putAll(entries);
  }

  Future<List<Purchase>> getAllPurchases() async {
    final box = await _getBox();
    final list = box.values.map((data) {
      final m = Map<String, dynamic>.from(data as Map);
      final itemsData = m['items'] as List? ?? [];
      final items = itemsData
          .map((i) => PurchaseItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
      return Purchase.fromMap(m, items: items);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Purchase> savePurchase(Purchase p) async {
    final box = await _getBox();
    final data = p.toMap();
    data['items'] = p.items.map((i) => i.toMap()).toList();

    await box.put(p.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
          collection: 'purchases',
          documentId: p.id,
          action: SyncAction.create,
          data: data,
        );

    return p;
  }

  Future<void> deletePurchase(String id) async {
    final box = await _getBox();
    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'purchases',
      documentId: id,
      action: SyncAction.delete,
      data: {},
    );
  }

  String generateInvoiceNumber() {
    final now = DateTime.now();
    final seq = now.millisecondsSinceEpoch % 10000;
    return 'PUR-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-${seq.toString().padLeft(4, '0')}';
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return PurchaseRepository(user?.uid ?? 'unknown', ref);
});

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);

  final controller = StreamController<List<Purchase>>();

  void update() async {
    final list = await repo.getAllPurchases();
    if (!controller.isClosed) controller.add(list);
  }

  update();

  final boxFuture = repo._getBox();
  boxFuture.then((box) {
    if (!ref.mounted) return;
    final subscription = box.watch().listen((_) => update());
    ref.onDispose(() => subscription.cancel());
  });

  ref.onDispose(() => controller.close());
  return controller.stream;
});

class PurchaseNotifier extends Notifier<void> {
  PurchaseRepository get _repo => ref.read(purchaseRepositoryProvider);

  @override
  void build() {}

  Future<Purchase> completePurchase({
    required String paymentMethod,
    required double amountPaid,
    String? notes,
  }) async {
    final cart = ref.read(purchaseCartProvider);
    final settings = ref.read(settingsProvider);
    final prodRepo = ref.read(productRepositoryProvider);
    final restockRepo = ref.read(restockRepositoryProvider);

    final purchaseId = _uuid.v4();
    final invoice = _repo.generateInvoiceNumber();

    final status = amountPaid >= cart.total
        ? PaymentStatus.paid
        : (amountPaid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid);

    final items = cart.items.map((item) {
      return PurchaseItem(
        id: _uuid.v4(),
        purchaseId: purchaseId,
        productId: item.product.id,
        productName: item.product.name,
        unitName: item.unit.unitName,
        conversionRate: item.unit.conversionRate,
        quantity: item.quantity,
        purchasePrice: item.purchasePrice,
        subtotal: item.subtotal,
      );
    }).toList();

    final now = DateTime.now();
    final purchase = Purchase(
      id: purchaseId,
      invoiceNumber: invoice,
      supplierId: cart.supplierId,
      supplierName: cart.supplierName,
      staffName: settings.ownerName.isEmpty ? 'Admin' : settings.ownerName,
      subtotal: cart.subtotal,
      shippingFee: cart.shippingFee,
      total: cart.total,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      paymentStatus: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      items: items,
    );

    // 1. Save Purchase Record
    await _repo.savePurchase(purchase);

    // 2. Process each item (Update Stock & Create Restock Record for History/Financials)
    for (final item in cart.items) {
      final baseQty = item.quantity * item.unit.conversionRate;

      // Update stock
      await prodRepo.updateStock(item.product.id, baseQty);

      // Calculate allocation of shipping fee per item based on value weight
      final weight = item.subtotal / cart.subtotal;
      final allocatedShipping = cart.shippingFee * weight;
      final totalCostPerBaseUnit =
          (item.subtotal + allocatedShipping) / baseQty;

      final restock = RestockRecord(
        id: _uuid.v4(),
        productId: item.product.id,
        productName: item.product.name,
        quantityAdded: baseQty,
        unitName: item.unit.unitName,
        supplierPrice: item.subtotal,
        shippingCost: allocatedShipping,
        totalCostPerUnit: totalCostPerBaseUnit,
        sellingPrice: item.product.basePrice, // Keep existing selling price
        supplierPaidAmount: (amountPaid / cart.total) * item.subtotal,
        shippingPaidAmount: (amountPaid / cart.total) * allocatedShipping,
        supplierName: cart.supplierName,
        supplierPaymentStatus: status,
        shippingServiceName:
            null, // Multi-item purchase usually has one shipping for all
        shippingPaymentStatus: status,
        createdAt: now,
        notes: 'Dari Pembelian: ${purchase.invoiceNumber}. ${notes ?? ""}',
      );

      await restockRepo.saveRestock(restock);
      await restockRepo.syncLatestFinancials(item.product.id);
    }

    // 3. Clear Cart and Notify
    ref.read(purchaseCartProvider.notifier).clear();
    ref.invalidate(productsProvider);
    ref.invalidate(purchasesProvider);
    ref.invalidate(restockHistoryProvider);

    return purchase;
  }

  Future<void> deletePurchase(String id) async {
    try {
      final box = await _repo._getBox();
      final data = box.get(id);
      if (data == null) return;

      final m = Map<String, dynamic>.from(data as Map);
      final itemsData = m['items'] as List? ?? [];
      final items = itemsData
          .map((i) => PurchaseItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
      final p = Purchase.fromMap(m, items: items);

      final prodRepo = ref.read(productRepositoryProvider);
      final restockRepo = ref.read(restockRepositoryProvider);

      // 1. Revert Stock & Delete Linked Restock Records
      for (final item in p.items) {
        await prodRepo.updateStock(
            item.productId, -(item.quantity * item.conversionRate));

        final restocks = await ref.read(restockHistoryProvider.future);
        final linkedRestock = restocks.firstWhereOrNull((r) =>
            r.productId == item.productId &&
            r.notes != null &&
            r.notes!.contains(p.invoiceNumber));

        if (linkedRestock != null) {
          await restockRepo.deleteRestock(linkedRestock);
        }
      }

      // 2. Delete Main Purchase Record
      await _repo.deletePurchase(id);

      // 3. Invalidate related providers
      ref.invalidate(productsProvider);
      ref.invalidate(purchasesProvider);
      ref.invalidate(restockHistoryProvider);
    } catch (e) {
      debugPrint('Error deleting purchase: $e');
      rethrow;
    }
  }
}

final purchaseActionProvider =
    NotifierProvider<PurchaseNotifier, void>(PurchaseNotifier.new);
