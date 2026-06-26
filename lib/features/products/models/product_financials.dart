enum PaymentStatus {
  paid,
  unpaid,
  notApplicable,
}

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Sudah Bayar';
      case PaymentStatus.unpaid:
        return 'Belum Bayar';
      case PaymentStatus.notApplicable:
        return 'N/A';
    }
  }
}

class ProductFinancials {
  final double supplierPrice;
  final double supplierShippingCost;
  final bool isManualCost;
  final String? supplierName;
  final PaymentStatus supplierPaymentStatus;
  final String? shippingServiceName;
  final PaymentStatus shippingPaymentStatus;

  const ProductFinancials({
    this.supplierPrice = 0,
    this.supplierShippingCost = 0,
    this.isManualCost = false,
    this.supplierName,
    this.supplierPaymentStatus = PaymentStatus.notApplicable,
    this.shippingServiceName,
    this.shippingPaymentStatus = PaymentStatus.notApplicable,
  });

  factory ProductFinancials.fromMap(Map<String, dynamic> m) => ProductFinancials(
        supplierPrice: (m['supplier_price'] as num? ?? 0).toDouble(),
        supplierShippingCost: (m['supplier_shipping_cost'] as num? ?? 0).toDouble(),
        isManualCost: m['is_manual_cost'] as bool? ?? false,
        supplierName: m['supplier_name'] as String?,
        supplierPaymentStatus: PaymentStatus.values.byName(m['supplier_payment_status'] as String? ?? 'notApplicable'),
        shippingServiceName: m['shipping_service_name'] as String?,
        shippingPaymentStatus: PaymentStatus.values.byName(m['shipping_payment_status'] as String? ?? 'notApplicable'),
      );

  Map<String, dynamic> toMap() => {
        'supplier_price': supplierPrice,
        'supplier_shipping_cost': supplierShippingCost,
        'is_manual_cost': isManualCost,
        'supplier_name': supplierName,
        'supplier_payment_status': supplierPaymentStatus.name,
        'shipping_service_name': shippingServiceName,
        'shipping_payment_status': shippingPaymentStatus.name,
      };

  ProductFinancials copyWith({
    double? supplierPrice,
    double? supplierShippingCost,
    bool? isManualCost,
    String? supplierName,
    PaymentStatus? supplierPaymentStatus,
    String? shippingServiceName,
    PaymentStatus? shippingPaymentStatus,
  }) =>
      ProductFinancials(
        supplierPrice: supplierPrice ?? this.supplierPrice,
        supplierShippingCost: supplierShippingCost ?? this.supplierShippingCost,
        isManualCost: isManualCost ?? this.isManualCost,
        supplierName: supplierName ?? this.supplierName,
        supplierPaymentStatus: supplierPaymentStatus ?? this.supplierPaymentStatus,
        shippingServiceName: shippingServiceName ?? this.shippingServiceName,
        shippingPaymentStatus: shippingPaymentStatus ?? this.shippingPaymentStatus,
      );
}
