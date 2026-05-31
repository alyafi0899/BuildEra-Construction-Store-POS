class TransactionItem {
  final String id;
  final String transactionId;
  final String productId;
  final String productName;
  final String unitName;
  final double conversionRate;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.conversionRate,
    required this.quantity,
    required this.unitPrice,
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
        unitPrice:      (m['unit_price'] as num).toDouble(),
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
        'unit_price':      unitPrice,
        'subtotal':        subtotal,
      };
}

class Transaction {
  final String id;
  final String invoiceNumber;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final double changeAmount;
  final String? notes;
  final DateTime createdAt;
  final List<TransactionItem> items;

  const Transaction({
    required this.id,
    required this.invoiceNumber,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory Transaction.fromMap(Map<String, dynamic> m, {List<TransactionItem> items = const []}) =>
      Transaction(
        id:            m['id'] as String,
        invoiceNumber: m['invoice_number'] as String,
        subtotal:      (m['subtotal'] as num).toDouble(),
        discount:      (m['discount'] as num).toDouble(),
        taxRate:       (m['tax_rate'] as num).toDouble(),
        taxAmount:     (m['tax_amount'] as num).toDouble(),
        total:         (m['total'] as num).toDouble(),
        paymentMethod: m['payment_method'] as String,
        amountPaid:    (m['amount_paid'] as num).toDouble(),
        changeAmount:  (m['change_amount'] as num).toDouble(),
        notes:         m['notes'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        items:         items,
      );

  Map<String, dynamic> toMap() => {
        'id':             id,
        'invoice_number': invoiceNumber,
        'subtotal':       subtotal,
        'discount':       discount,
        'tax_rate':       taxRate,
        'tax_amount':     taxAmount,
        'total':          total,
        'payment_method': paymentMethod,
        'amount_paid':    amountPaid,
        'change_amount':  changeAmount,
        'notes':          notes,
        'created_at':     createdAt.toIso8601String(),
      };
}
