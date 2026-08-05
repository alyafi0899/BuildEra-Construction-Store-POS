import '../../features/cashier/models/cart_item.dart';

class TransactionItem {
  final String id;
  final String transactionId;
  final String productId;
  final String productName;
  final String unitName;
  final double conversionRate;
  final double quantity;
  final double costPrice;
  final double originalPrice;
  final double soldPrice;
  final double discountValue;
  final DiscountType discountType;
  final double subtotal;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.conversionRate,
    required this.quantity,
    required this.costPrice,
    required this.originalPrice,
    required this.soldPrice,
    required this.discountValue,
    required this.discountType,
    required this.subtotal,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> m) => TransactionItem(
        id:             m['id'] as String,
        transactionId:  m['transaction_id'] as String,
        productId:      m['product_id'] as String,
        productName:    m['product_name'] as String,
        unitName:       m['unit_name'] as String,
        conversionRate: (m['conversion_rate'] as num).toDouble(),
        quantity:       (m['quantity'] as num).toDouble(),
        costPrice:      (m['cost_price'] as num? ?? 0).toDouble(),
        originalPrice:  (m['original_price'] as num? ?? m['unit_price'] ?? 0).toDouble(),
        soldPrice:      (m['sold_price'] as num? ?? m['unit_price'] ?? 0).toDouble(),
        discountValue:  (m['discount_value'] as num? ?? 0).toDouble(),
        discountType:   DiscountType.values.firstWhere((e) => e.name == (m['discount_type'] ?? 'fixed'), orElse: () => DiscountType.fixed),
        subtotal:       (m['subtotal'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'transaction_id':  transactionId,
        'product_id':      productId,
        'product_name':    productName,
        'unit_name':       unitName,
        'conversion_rate': conversionRate,
        'quantity':        quantity,
        'cost_price':      costPrice,
        'original_price':  originalPrice,
        'sold_price':      soldPrice,
        'discount_value':  discountValue,
        'discount_type':   discountType.name,
        'subtotal':        subtotal,
      };

  double get totalDiscount {
    if (discountType == DiscountType.percentage) {
      return (originalPrice * quantity) * (discountValue / 100);
    }
    return discountValue * quantity;
  }
}

class Transaction {
  final String id;
  final String invoiceNumber;
  final String? customerId; 
  final String? customerName;
  final String? cashierName;
  final double subtotal; 
  final double itemDiscountTotal; 
  final double transDiscountValue;
  final DiscountType transDiscountType;
  final double transDiscountAmount;
  final double taxRate;
  final double taxAmount;
  final double shippingFee; // New
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final double changeAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TransactionItem> items;

  const Transaction({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.cashierName,
    required this.subtotal,
    required this.itemDiscountTotal,
    required this.transDiscountValue,
    required this.transDiscountType,
    required this.transDiscountAmount,
    required this.taxRate,
    required this.taxAmount,
    this.shippingFee = 0, // New
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory Transaction.fromMap(Map<String, dynamic> m, {List<TransactionItem> items = const []}) =>
      Transaction(
        id:                 m['id'] as String,
        invoiceNumber:      m['invoice_number'] as String,
        customerId:         m['customer_id'] as String?,
        customerName:       m['customer_name'] as String?,
        cashierName:        m['cashier_name'] as String?,
        subtotal:           (m['subtotal'] as num).toDouble(),
        itemDiscountTotal:  (m['item_discount_total'] as num? ?? 0).toDouble(),
        transDiscountValue: (m['trans_discount_value'] as num? ?? m['discount'] ?? 0).toDouble(),
        transDiscountType:  DiscountType.values.firstWhere((e) => e.name == (m['trans_discount_type'] ?? 'fixed'), orElse: () => DiscountType.fixed),
        transDiscountAmount:(m['trans_discount_amount'] as num? ?? m['discount'] ?? 0).toDouble(),
        taxRate:            (m['tax_rate'] as num).toDouble(),
        taxAmount:          (m['tax_amount'] as num).toDouble(),
        shippingFee:        (m['shipping_fee'] as num? ?? 0).toDouble(), // New
        total:              (m['total'] as num).toDouble(),
        paymentMethod:      m['payment_method'] as String,
        amountPaid:         (m['amount_paid'] as num).toDouble(),
        changeAmount:       (m['change_amount'] as num).toDouble(),
        notes:              m['notes'] as String?,
        createdAt:          DateTime.parse(m['created_at'] as String),
        updatedAt:          m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : DateTime.parse(m['created_at'] as String),
        items:              items,
      );

  Map<String, dynamic> toMap() => {
        'id':                    id,
        'invoice_number':        invoiceNumber,
        'customer_id':           customerId,
        'customer_name':         customerName,
        'cashier_name':          cashierName,
        'subtotal':              subtotal,
        'item_discount_total':   itemDiscountTotal,
        'trans_discount_value':  transDiscountValue,
        'trans_discount_type':   transDiscountType.name,
        'trans_discount_amount': transDiscountAmount,
        'tax_rate':              taxRate,
        'tax_amount':            taxAmount,
        'shipping_fee':          shippingFee, // New
        'total':                 total,
        'payment_method':        paymentMethod,
        'amount_paid':           amountPaid,
        'change_amount':         changeAmount,
        'notes':                 notes,
        'created_at':            createdAt.toIso8601String(),
        'updated_at':            updatedAt.toIso8601String(),
      };
}
