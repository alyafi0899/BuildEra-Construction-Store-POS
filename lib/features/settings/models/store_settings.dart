import 'dart:convert';

class BankAccount {
  final String bankName;
  final String accountNumber;
  final String accountHolder;

  const BankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });

  Map<String, dynamic> toMap() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
    };
  }

  factory BankAccount.fromMap(Map<dynamic, dynamic> map) {
    return BankAccount(
      bankName: map['bank_name']?.toString() ?? map['bankName']?.toString() ?? '',
      accountNumber: map['account_number']?.toString() ?? map['accountNumber']?.toString() ?? '',
      accountHolder: map['account_holder']?.toString() ?? map['accountHolder']?.toString() ?? '',
    );
  }
}

class StoreSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String email; // Business email
  final String? loginEmail; 
  final String address;
  final String description;
  final List<BankAccount> bankAccounts;
  final String? logoUrl;
  final String? qrisImagePath; 
  final String? securityPin; 
  final bool lockAnalyticsPage; 
  final bool lockProductsPage; 
  final bool lockInventoryPage; 
  final double receiptWidth;
  final double receiptMargin;
  final bool useFastPrint; 
  final String printerTransport;
  final String invoiceDesign; 
  final String printMethod;   
  final String? invoicePrinterUrl; 
  final String? labelPrinterUrl;   

  const StoreSettings({
    this.businessName = '',
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.loginEmail,
    this.address = '',
    this.description = '',
    this.bankAccounts = const [],
    this.logoUrl,
    this.qrisImagePath,
    this.securityPin,
    this.lockAnalyticsPage = true,
    this.lockProductsPage = true,
    this.lockInventoryPage = true,
    this.receiptWidth = 80.0,
    this.receiptMargin = 4.0,
    this.useFastPrint = false,
    this.printerTransport = 'pdf',
    this.invoiceDesign = 'classic',
    this.printMethod = 'pdf',
    this.invoicePrinterUrl,
    this.labelPrinterUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'business_name': businessName,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'login_email': loginEmail,
      'address': address,
      'description': description,
      'bank_accounts': bankAccounts.map((x) => x.toMap()).toList(),
      'logo_url': logoUrl,
      'qris_image_path': qrisImagePath,
      'security_pin': securityPin,
      'lock_analytics_page': lockAnalyticsPage,
      'lock_products_page': lockProductsPage,
      'lock_inventory_page': lockInventoryPage,
      'receipt_width': receiptWidth,
      'receipt_margin': receiptMargin,
      'use_fast_print': useFastPrint,
      'printer_transport': printerTransport,
      'invoice_design': invoiceDesign,
      'print_method': printMethod,
      'invoice_printer_url': invoicePrinterUrl,
      'label_printer_url': labelPrinterUrl,
    };
  }

  factory StoreSettings.fromMap(Map<dynamic, dynamic> map) {
    return StoreSettings(
      businessName: map['business_name']?.toString() ?? map['businessName']?.toString() ?? '',
      ownerName: map['owner_name']?.toString() ?? map['ownerName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      loginEmail: map['login_email']?.toString() ?? map['loginEmail']?.toString(),
      address: map['address']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      bankAccounts: (map['bank_accounts'] as List? ?? map['bankAccounts'] as List?)
              ?.map((x) => BankAccount.fromMap(x as Map))
              .toList() ??
          [],
      logoUrl: map['logo_url']?.toString() ?? map['logoUrl']?.toString(),
      qrisImagePath: map['qris_image_path']?.toString() ?? map['qrisImagePath']?.toString(),
      securityPin: map['security_pin']?.toString() ?? map['securityPin']?.toString(),
      lockAnalyticsPage: (map['lock_analytics_page'] ?? map['lockAnalyticsPage']) as bool? ?? true,
      lockProductsPage: (map['lock_products_page'] ?? map['lockProductsPage']) as bool? ?? true,
      lockInventoryPage: (map['lock_inventory_page'] ?? map['lockInventoryPage']) as bool? ?? true,
      receiptWidth: (map['receipt_width'] as num? ?? map['receiptWidth'] as num?)?.toDouble() ?? 80.0,
      receiptMargin: (map['receipt_margin'] as num? ?? map['receiptMargin'] as num?)?.toDouble() ?? 4.0,
      useFastPrint: (map['use_fast_print'] ?? map['useFastPrint']) as bool? ?? false,
      printerTransport: map['printer_transport']?.toString() ?? map['printerTransport']?.toString() ?? 'pdf',
      invoiceDesign: map['invoice_design']?.toString() ?? map['invoiceDesign']?.toString() ?? 'classic',
      printMethod: map['print_method']?.toString() ?? map['printMethod']?.toString() ?? 'pdf',
      invoicePrinterUrl: map['invoice_printer_url']?.toString() ?? map['invoicePrinterUrl']?.toString(),
      labelPrinterUrl: map['label_printer_url']?.toString() ?? map['labelPrinterUrl']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreSettings.fromJson(String source) => StoreSettings.fromMap(json.decode(source));

  StoreSettings copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? email,
    String? loginEmail,
    String? address,
    String? description,
    List<BankAccount>? bankAccounts,
    String? logoUrl,
    String? qrisImagePath,
    String? securityPin,
    bool? lockAnalyticsPage,
    bool? lockProductsPage,
    bool? lockInventoryPage,
    double? receiptWidth,
    double? receiptMargin,
    bool? useFastPrint,
    String? printerTransport,
    String? invoiceDesign,
    String? printMethod,
    String? invoicePrinterUrl,
    String? labelPrinterUrl,
  }) {
    return StoreSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      loginEmail: loginEmail ?? this.loginEmail,
      address: address ?? this.address,
      description: description ?? this.description,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      logoUrl: logoUrl ?? this.logoUrl,
      qrisImagePath: qrisImagePath ?? this.qrisImagePath,
      securityPin: securityPin ?? this.securityPin,
      lockAnalyticsPage: lockAnalyticsPage ?? this.lockAnalyticsPage,
      lockProductsPage: lockProductsPage ?? this.lockProductsPage,
      lockInventoryPage: lockInventoryPage ?? this.lockInventoryPage,
      receiptWidth: receiptWidth ?? this.receiptWidth,
      receiptMargin: receiptMargin ?? this.receiptMargin,
      useFastPrint: useFastPrint ?? this.useFastPrint,
      printerTransport: printerTransport ?? this.printerTransport,
      invoiceDesign: invoiceDesign ?? this.invoiceDesign,
      printMethod: printMethod ?? this.printMethod,
      invoicePrinterUrl: invoicePrinterUrl ?? this.invoicePrinterUrl,
      labelPrinterUrl: labelPrinterUrl ?? this.labelPrinterUrl,
    );
  }
}
