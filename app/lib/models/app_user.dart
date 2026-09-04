class AppUser {
  final String id; // local PayFlex user id (Postgres row)
  final String bmoniUserId;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String? ownerAddress;

  AppUser({
    required this.id,
    required this.bmoniUserId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.ownerAddress,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        bmoniUserId: json['bmoniUserId'] as String,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
        email: json['email'] as String,
        phoneNumber: json['phoneNumber'] as String,
        ownerAddress: json['ownerAddress'] as String?,
      );
}

class SmartWallet {
  final String id;
  final String currency;
  final String walletAddress;
  final bool isActive;

  SmartWallet({
    required this.id,
    required this.currency,
    required this.walletAddress,
    required this.isActive,
  });

  factory SmartWallet.fromJson(Map<String, dynamic> json) => SmartWallet(
        id: json['id'] as String,
        currency: json['currency'] as String,
        walletAddress: json['walletAddress'] as String,
        isActive: json['isActive'] as bool,
      );
}
