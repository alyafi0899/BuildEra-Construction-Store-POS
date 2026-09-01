import '../../features/products/models/product_financials.dart';

class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final String unitName;
  final double conversionRate;
  final double quantity;
  final double purchasePrice; // Price per base unit
  final double subtotal;

  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.conversionRate,
    required this.quantity,
    required this.purchasePrice,
    required this.subtotal,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        id:             m['id'] as String,
        purchaseId:     m['purchase_id'] as String,
        productId:      m['product_id'] as String,
        productName:    m['product_name'] as String,
        unitName:       m['unit_name'] as String,
        conversionRate: (m['conversion_rate'] as num).toDouble(),
        quantity:       (m['quantity'] as num).toDouble(),
        purchasePrice:  (m['purchase_price'] as num).toDouble(),
        subtotal:       (m['subtotal'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'purchase_id':     purchaseId,
        'product_id':      productId,
        'product_name':    productName,
        'unit_name':       unitName,
        'conversion_rate': conversionRate,
        'quantity':        quantity,
        'purchase_price':  purchasePrice,
        'subtotal':        subtotal,
      };
}

class Purchase {
  final String id;
  final String invoiceNumber;
  final String? supplierId;
  final String? supplierName;
  final String? staffName;
  final double subtotal;
  final double shippingFee;
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final PaymentStatus paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseItem> items;

  const Purchase({
    required this.id,
    required this.invoiceNumber,
    this.supplierId,
    this.supplierName,
    this.staffName,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory Purchase.fromMap(Map<String, dynamic> m, {List<PurchaseItem> items = const []}) =>
      Purchase(
        id:             m['id'] as String,
        invoiceNumber:  m['invoice_number'] as String,
        supplierId:     m['supplier_id'] as String?,
        supplierName:   m['supplier_name'] as String?,
        staffName:      m['staff_name'] as String?,
        subtotal:       (m['subtotal'] as num).toDouble(),
        shippingFee:    (m['shipping_fee'] as num? ?? 0).toDouble(),
        total:          (m['total'] as num).toDouble(),
        paymentMethod:  m['payment_method'] as String,
        amountPaid:     (m['amount_paid'] as num).toDouble(),
        paymentStatus:  PaymentStatus.values.byName(m['payment_status'] as String? ?? 'paid'),
        notes:          m['notes'] as String?,
        createdAt:      DateTime.parse(m['created_at'] as String),
        updatedAt:      m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : DateTime.parse(m['created_at'] as String),
        items:          items,
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'invoice_number':  invoiceNumber,
        'supplier_id':     supplierId,
        'supplier_name':   supplierName,
        'staff_name':      staffName,
        'subtotal':        subtotal,
        'shipping_fee':    shippingFee,
        'total':           total,
        'payment_method':  paymentMethod,
        'amount_paid':     amountPaid,
        'payment_status':  paymentStatus.name,
        'notes':           notes,
        'created_at':      createdAt.toIso8601String(),
        'updated_at':      updatedAt.toIso8601String(),
      };
}
