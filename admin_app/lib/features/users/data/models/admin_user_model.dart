import 'package:equatable/equatable.dart';

class AdminUserModel extends Equatable {
  final String id;
  final String? email;
  final String phoneNumber;
  final String fullName;
  final String role;
  final String profileImageUrl;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isActive;
  final DateTime createdAt;

  const AdminUserModel({
    required this.id,
    this.email,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.profileImageUrl,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) => AdminUserModel(
        id: json['id'] as String,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? 'customer',
        profileImageUrl: json['profile_image_url'] as String? ?? '',
        isEmailVerified: json['is_email_verified'] as bool? ?? false,
        isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

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
