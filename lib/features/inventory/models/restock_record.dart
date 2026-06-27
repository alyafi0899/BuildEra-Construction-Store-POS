import '../../products/models/product_financials.dart';

class RestockRecord {
  final String id;
  final String productId;
  final String productName;
  final double quantityAdded;
  final String unitName;
  final double supplierPrice;
  final double shippingCost;
  final double totalCostPerUnit;
  final double sellingPrice;
  final double supplierPaidAmount; // New
  final double shippingPaidAmount; // New
  final String? supplierName;
  final PaymentStatus supplierPaymentStatus;
  final String? shippingServiceName;
  final PaymentStatus shippingPaymentStatus;
  final DateTime createdAt;
  final String? notes;

  const RestockRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityAdded,
    required this.unitName,
    required this.supplierPrice,
    required this.shippingCost,
    required this.totalCostPerUnit,
    required this.sellingPrice,
    this.supplierPaidAmount = 0,
    this.shippingPaidAmount = 0,
    this.supplierName,
    required this.supplierPaymentStatus,
    this.shippingServiceName,
    required this.shippingPaymentStatus,
    required this.createdAt,
    this.notes,
  });

  factory RestockRecord.fromMap(Map<String, dynamic> m) => RestockRecord(
        id:                    m['id'] as String,
        productId:             m['product_id'] as String,
        productName:           m['product_name'] as String,
        quantityAdded:         (m['quantity_added'] as num).toDouble(),
        unitName:              m['unit_name'] as String,
        supplierPrice:         (m['supplier_price'] as num).toDouble(),
        shippingCost:          (m['shipping_cost'] as num).toDouble(),
        totalCostPerUnit:      (m['total_cost_per_unit'] as num).toDouble(),
        sellingPrice:          (m['selling_price'] as num? ?? 0).toDouble(),
        supplierPaidAmount:    (m['supplier_paid_amount'] as num? ?? 0).toDouble(),
        shippingPaidAmount:    (m['shipping_paid_amount'] as num? ?? 0).toDouble(),
        supplierName:          m['supplier_name'] as String?,
        supplierPaymentStatus: PaymentStatus.values.byName(m['supplier_payment_status'] as String? ?? 'notApplicable'),
        shippingServiceName:   m['shipping_service_name'] as String?,
        shippingPaymentStatus: PaymentStatus.values.byName(m['shipping_payment_status'] as String? ?? 'notApplicable'),
        createdAt:             DateTime.parse(m['created_at'] as String),
        notes:                 m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':                      id,
        'product_id':              productId,
        'product_name':            productName,
        'quantity_added':          quantityAdded,
        'unit_name':               unitName,
        'supplier_price':          supplierPrice,
        'shipping_cost':           shippingCost,
        'total_cost_per_unit':     totalCostPerUnit,
        'selling_price':           sellingPrice,
        'supplier_paid_amount':    supplierPaidAmount,
        'shipping_paid_amount':    shippingPaidAmount,
        'supplier_name':           supplierName,
        'supplier_payment_status': supplierPaymentStatus.name,
        'shipping_service_name':   shippingServiceName,
        'shipping_payment_status': shippingPaymentStatus.name,
        'created_at':              createdAt.toIso8601String(),
        'notes':                   notes,
      };

  RestockRecord copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantityAdded,
    String? unitName,
    double? supplierPrice,
    double? shippingCost,
    double? totalCostPerUnit,
    double? sellingPrice,
    double? supplierPaidAmount,
    double? shippingPaidAmount,
    String? supplierName,
    PaymentStatus? supplierPaymentStatus,
    String? shippingServiceName,
    PaymentStatus? shippingPaymentStatus,
    DateTime? createdAt,
    String? notes,
  }) =>
      RestockRecord(
        id:                    id ?? this.id,
        productId:             productId ?? this.productId,
        productName:           productName ?? this.productName,
        quantityAdded:         quantityAdded ?? this.quantityAdded,
        unitName:              unitName ?? this.unitName,
        supplierPrice:         supplierPrice ?? this.supplierPrice,
        shippingCost:          shippingCost ?? this.shippingCost,
        totalCostPerUnit:      totalCostPerUnit ?? this.totalCostPerUnit,
        sellingPrice:          sellingPrice ?? this.sellingPrice,
        supplierPaidAmount:    supplierPaidAmount ?? this.supplierPaidAmount,
        shippingPaidAmount:    shippingPaidAmount ?? this.shippingPaidAmount,
        supplierName:          supplierName ?? this.supplierName,
        supplierPaymentStatus: supplierPaymentStatus ?? this.supplierPaymentStatus,
        shippingServiceName:   shippingServiceName ?? this.shippingServiceName,
        shippingPaymentStatus: shippingPaymentStatus ?? this.shippingPaymentStatus,
        createdAt:             createdAt ?? this.createdAt,
        notes:                 notes ?? this.notes,
      );
}
