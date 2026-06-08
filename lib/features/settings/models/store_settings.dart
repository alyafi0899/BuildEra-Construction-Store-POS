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

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountHolder: map['accountHolder'] ?? '',
    );
  }
}

class StoreSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String description;
  final List<BankAccount> bankAccounts;
  final String? logoUrl;

  const StoreSettings({
    this.businessName = '',
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.description = '',
    this.bankAccounts = const [],
    this.logoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'description': description,
      'bankAccounts': bankAccounts.map((x) => x.toMap()).toList(),
      'logoUrl': logoUrl,
    };
  }

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      businessName: map['businessName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      description: map['description'] ?? '',
      bankAccounts: (map['bankAccounts'] as List?)
              ?.map((x) => BankAccount.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      logoUrl: map['logoUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreSettings.fromJson(String source) => StoreSettings.fromMap(json.decode(source));

  StoreSettings copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    String? description,
    List<BankAccount>? bankAccounts,
    String? logoUrl,
  }) {
    return StoreSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      description: description ?? this.description,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
