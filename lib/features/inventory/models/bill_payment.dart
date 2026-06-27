class BillPayment {
  final String id;
  final String billId; // Can be Product ID (initial) or Restock ID
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final bool isInitialBill;

  const BillPayment({
    required this.id,
    required this.billId,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.isInitialBill,
  });

  factory BillPayment.fromMap(Map<String, dynamic> m) => BillPayment(
        id:            m['id'] as String,
        billId:        m['bill_id'] as String,
        amount:        (m['amount'] as num).toDouble(),
        notes:         m['notes'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        isInitialBill: m['is_initial_bill'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'bill_id':         billId,
        'amount':          amount,
        'notes':           notes,
        'created_at':      createdAt.toIso8601String(),
        'is_initial_bill': isInitialBill,
      };

  BillPayment copyWith({
    String? id,
    String? billId,
    double? amount,
    String? notes,
    DateTime? createdAt,
    bool? isInitialBill,
  }) =>
      BillPayment(
        id:            id ?? this.id,
        billId:        billId ?? this.billId,
        amount:        amount ?? this.amount,
        notes:         notes ?? this.notes,
        createdAt:     createdAt ?? this.createdAt,
        isInitialBill: isInitialBill ?? this.isInitialBill,
      );
}
