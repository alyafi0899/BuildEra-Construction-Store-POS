enum DebtStatus { unpaid, partiallyPaid, paid, overdue }

class Debt {
  final String id;
  final String transactionId;
  final String customerId;
  final String customerName;
  final String invoiceNumber;
  final double totalAmount;
  final double paidAmount;
  final double remainingBalance;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime updatedAt; // New
  final DebtStatus status;
  final String? notes;

  const Debt({
    required this.id,
    required this.transactionId,
    required this.customerId,
    required this.customerName,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingBalance,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.notes,
  });

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
        id:               m['id'] as String,
        transactionId:    m['transaction_id'] as String,
        customerId:       m['customer_id'] as String,
        customerName:     m['customer_name'] as String,
        invoiceNumber:    m['invoice_number'] as String,
        totalAmount:      (m['total_amount'] as num).toDouble(),
        paidAmount:       (m['paid_amount'] as num).toDouble(),
        remainingBalance: (m['remaining_balance'] as num).toDouble(),
        dueDate:          DateTime.parse(m['due_date'] as String),
        createdAt:        DateTime.parse(m['created_at'] as String),
        updatedAt:        m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : DateTime.parse(m['created_at'] as String),
        status:           DebtStatus.values.byName(m['status'] as String),
        notes:            m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id':                id,
        'transaction_id':    transactionId,
        'customer_id':       customerId,
        'customer_name':     customerName,
        'invoice_number':    invoiceNumber,
        'total_amount':      totalAmount,
        'paid_amount':       paidAmount,
        'remaining_balance': remainingBalance,
        'due_date':          dueDate.toIso8601String(),
        'created_at':        createdAt.toIso8601String(),
        'updated_at':        updatedAt.toIso8601String(),
        'status':            status.name,
        'notes':             notes,
      };

  Debt copyWith({
    double? paidAmount,
    double? remainingBalance,
    DebtStatus? status,
    DateTime? updatedAt,
  }) =>
      Debt(
        id:               id,
        transactionId:    transactionId,
        customerId:       customerId,
        customerName:     customerName,
        invoiceNumber:    invoiceNumber,
        totalAmount:      totalAmount,
        paidAmount:       paidAmount ?? this.paidAmount,
        remainingBalance: remainingBalance ?? this.remainingBalance,
        dueDate:          dueDate,
        createdAt:        createdAt,
        updatedAt:        updatedAt ?? this.updatedAt,
        status:           status ?? this.status,
        notes:            notes,
      );
      
  bool get isOverdue => status != DebtStatus.paid && DateTime.now().isAfter(dueDate);
}
