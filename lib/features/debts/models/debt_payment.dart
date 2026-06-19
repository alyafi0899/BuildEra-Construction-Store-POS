class DebtPayment {
  final String id;
  final String debtId;
  final String customerId;
  final double amount;
  final DateTime createdAt;
  final String? notes;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.customerId,
    required this.amount,
    required this.createdAt,
    this.notes,
  });

  factory DebtPayment.fromMap(Map<String, dynamic> m) => DebtPayment(
        id:         m['id'] as String,
        debtId:     m['debt_id'] as String,
        customerId: m['customer_id'] as String,
        amount:     (m['amount'] as num).toDouble(),
        createdAt:  DateTime.parse(m['created_at'] as String),
        notes:      m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'debt_id':     debtId,
        'customer_id': customerId,
        'amount':      amount,
        'created_at':  createdAt.toIso8601String(),
        'notes':       notes,
      };
}
