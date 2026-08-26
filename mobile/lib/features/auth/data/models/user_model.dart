import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String phoneNumber;
  final String fullName;
  final String role;
  final String? profileImageUrl;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.email,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.profileImageUrl,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['profile_image_url'] as String?;
    final rawEmail = json['email'] as String?;
    return UserModel(
      id: json['id'] as String,
      email: (rawEmail == null || rawEmail.isEmpty) ? null : rawEmail,
      phoneNumber: json['phone_number'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      profileImageUrl: (rawImageUrl == null || rawImageUrl.isEmpty) ? null : rawImageUrl,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone_number': phoneNumber,
        'full_name': fullName,
        'role': role,
        'profile_image_url': profileImageUrl,
        'is_email_verified': isEmailVerified,
        'is_phone_verified': isPhoneVerified,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isCustomer => role == 'customer';

  @override
  List<Object?> get props => [
        id,
        email,
        phoneNumber,
        fullName,
        role,
        profileImageUrl,
        isEmailVerified,
        isPhoneVerified,
        isActive,
        createdAt,
      ];
}
