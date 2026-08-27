import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String phoneNumber;
  final String fullName;
  final String role;

  const UserModel({
    required this.id,
    this.email,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? 'admin',
      );

  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [id, email, phoneNumber, fullName, role];
}

class AuthResultModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  const AuthResultModel({required this.user, required this.accessToken, required this.refreshToken});

  factory AuthResultModel.fromJson(Map<String, dynamic> json) => AuthResultModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
      );
}
