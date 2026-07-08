import '../../products/models/product_financials.dart';

class BillPayment {
  final String id;
  final String billId; 
  final String entityName; // New/Restored
  final String productName; // New/Restored
  final double amount;
  final PaymentStatus status; // New/Restored
  final String? notes;
  final DateTime createdAt;
  final bool isInitialBill;
  final bool isForSupplier;

  const BillPayment({
    required this.id,
    required this.billId,
    required this.entityName,
    required this.productName,
    required this.amount,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.isInitialBill,
    required this.isForSupplier,
  });

  factory BillPayment.fromMap(Map<String, dynamic> m) => BillPayment(
        id:            m['id'] as String,
        billId:        m['bill_id'] as String,
        entityName:    m['entity_name'] as String? ?? 'Umum',
        productName:   m['product_name'] as String? ?? 'Produk',
        amount:        (m['amount'] as num).toDouble(),
        status:        PaymentStatus.values.byName(m['status'] as String? ?? 'unpaid'),
        notes:         m['notes'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        isInitialBill: m['is_initial_bill'] as bool? ?? false,
        isForSupplier: m['is_for_supplier'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'bill_id':         billId,
        'entity_name':     entityName,
        'product_name':    productName,
        'amount':          amount,
        'status':          status.name,
        'notes':           notes,
        'created_at':      createdAt.toIso8601String(),
        'is_initial_bill': isInitialBill,
        'is_for_supplier': isForSupplier,
      };

  BillPayment copyWith({
    String? id,
    String? billId,
    String? entityName,
    String? productName,
    double? amount,
    PaymentStatus? status,
    String? notes,
    DateTime? createdAt,
    bool? isInitialBill,
    bool? isForSupplier,
  }) =>
      BillPayment(
        id:            id ?? this.id,
        billId:        billId ?? this.billId,
        entityName:    entityName ?? this.entityName,
        productName:   productName ?? this.productName,
        amount:        amount ?? this.amount,
        status:        status ?? this.status,
        notes:         notes ?? this.notes,
        createdAt:     createdAt ?? this.createdAt,
        isInitialBill: isInitialBill ?? this.isInitialBill,
        isForSupplier: isForSupplier ?? this.isForSupplier,
      );
}
