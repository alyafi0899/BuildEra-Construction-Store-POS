import 'dart:convert';

class StoreSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String description;
  final String bankName;
  final String bankAccount;
  final String bankHolder;
  final String? logoUrl;

  const StoreSettings({
    this.businessName = '',
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.description = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bankHolder = '',
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
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankHolder': bankHolder,
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
      bankName: map['bankName'] ?? '',
      bankAccount: map['bankAccount'] ?? '',
      bankHolder: map['bankHolder'] ?? '',
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
    String? bankName,
    String? bankAccount,
    String? bankHolder,
    String? logoUrl,
  }) {
    return StoreSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      description: description ?? this.description,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankHolder: bankHolder ?? this.bankHolder,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
