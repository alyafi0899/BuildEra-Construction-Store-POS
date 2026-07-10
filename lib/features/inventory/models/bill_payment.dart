class BillPayment {
  final String id;
  final String billId; 
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final bool isInitialBill;
  final bool isForSupplier; // New: To distinguish if this pays for goods or shipping

  const BillPayment({
    required this.id,
    required this.billId,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.isInitialBill,
    required this.isForSupplier,
  });

  factory BillPayment.fromMap(Map<String, dynamic> m) => BillPayment(
        id:            m['id'] as String,
        billId:        m['bill_id'] as String,
        amount:        (m['amount'] as num).toDouble(),
        notes:         m['notes'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        isInitialBill: m['is_initial_bill'] as bool? ?? false,
        isForSupplier: m['is_for_supplier'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'bill_id':         billId,
        'amount':          amount,
        'notes':           notes,
        'created_at':      createdAt.toIso8601String(),
        'is_initial_bill': isInitialBill,
        'is_for_supplier': isForSupplier,
      };

  BillPayment copyWith({
    String? id,
    String? billId,
    double? amount,
    String? notes,
    DateTime? createdAt,
    bool? isInitialBill,
    bool? isForSupplier,
  }) =>
      BillPayment(
        id:            id ?? this.id,
        billId:        billId ?? this.billId,
        amount:        amount ?? this.amount,
        notes:         notes ?? this.notes,
        createdAt:     createdAt ?? this.createdAt,
        isInitialBill: isInitialBill ?? this.isInitialBill,
        isForSupplier: isForSupplier ?? this.isForSupplier,
      );
}
