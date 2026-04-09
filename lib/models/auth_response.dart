import 'user.dart';

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken:
          json['access_token']?.toString() ?? json['token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      user: User.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
    );
  }
}
