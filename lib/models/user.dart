class User {
  final int id;
  final String name;
  final String email;
  final int celestialCoins;
  final String? referralCode;
  final bool hasPassword;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.celestialCoins = 0,
    this.referralCode,
    this.hasPassword = true,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Sin nombre',
      email: json['email']?.toString() ?? 'Sin email',
      celestialCoins:
          int.tryParse(json['celestial_coins']?.toString() ?? '0') ?? 0,
      referralCode: json['referral_code']?.toString(),
      hasPassword: json['has_password'] == null
          ? true
          : json['has_password'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'celestial_coins': celestialCoins,
      'referral_code': referralCode,
      'has_password': hasPassword,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
