import 'user_model.dart';

/// Bundles the tokens and user profile returned by register/login.
class AuthResultModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  const AuthResultModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResultModel.fromJson(Map<String, dynamic> json) => AuthResultModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
      );
}
