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
        id:               m['id']?.toString() ?? '',
        transactionId:    m['transaction_id']?.toString() ?? '',
        customerId:       m['customer_id']?.toString() ?? '',
        customerName:     m['customer_name']?.toString() ?? 'Umum',
        invoiceNumber:    m['invoice_number']?.toString() ?? '',
        totalAmount:      (m['total_amount'] as num? ?? 0).toDouble(),
        paidAmount:       (m['paid_amount'] as num? ?? 0).toDouble(),
        remainingBalance: (m['remaining_balance'] as num? ?? 0).toDouble(),
        dueDate:          DateTime.parse(m['due_date']?.toString() ?? DateTime.now().toIso8601String()),
        createdAt:        DateTime.parse(m['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        updatedAt:        m['updated_at'] != null ? DateTime.parse(m['updated_at'].toString()) : DateTime.parse(m['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        status:           DebtStatus.values.byName(m['status']?.toString() ?? 'unpaid'),
        notes:            m['notes']?.toString(),
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
