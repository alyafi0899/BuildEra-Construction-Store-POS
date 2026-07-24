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
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
    };
  }

  factory BankAccount.fromMap(Map<dynamic, dynamic> map) {
    return BankAccount(
      bankName: map['bankName']?.toString() ?? '',
      accountNumber: map['accountNumber']?.toString() ?? '',
      accountHolder: map['accountHolder']?.toString() ?? '',
    );
  }
}

class StoreSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String email; // Business email
  final String? loginEmail; // New: For security checks
  final String address;
  final String description;
  final List<BankAccount> bankAccounts;
  final String? logoUrl;
  final String? qrisImagePath; // New: Local path for QRIS barcode
  final String? securityPin; // New: PIN for sensitive data
  final double receiptWidth; // New: Receipt paper width in mm

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
    this.receiptWidth = 80.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'loginEmail': loginEmail,
      'address': address,
      'description': description,
      'bankAccounts': bankAccounts.map((x) => x.toMap()).toList(),
      'logoUrl': logoUrl,
      'qrisImagePath': qrisImagePath,
      'securityPin': securityPin,
      'receiptWidth': receiptWidth,
    };
  }

  factory StoreSettings.fromMap(Map<dynamic, dynamic> map) {
    return StoreSettings(
      businessName: map['businessName']?.toString() ?? '',
      ownerName: map['ownerName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      loginEmail: map['loginEmail']?.toString(),
      address: map['address']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      bankAccounts: (map['bankAccounts'] as List?)
              ?.map((x) => BankAccount.fromMap(x as Map))
              .toList() ??
          [],
      logoUrl: map['logoUrl']?.toString(),
      qrisImagePath: map['qrisImagePath']?.toString(),
      securityPin: map['securityPin']?.toString(),
      receiptWidth: (map['receiptWidth'] as num?)?.toDouble() ?? 80.0,
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
    double? receiptWidth,
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
      receiptWidth: receiptWidth ?? this.receiptWidth,
    );
  }
}
