import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

class DeliveryPartnerAdminModel extends Equatable {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String vehicleType;
  final String vehicleNumber;
  final String licenseNumber;
  final String status;
  final bool isVerified;
  final double ratingAvg;
  final int totalDeliveries;
  final DateTime createdAt;

  const DeliveryPartnerAdminModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.licenseNumber,
    required this.status,
    required this.isVerified,
    required this.ratingAvg,
    required this.totalDeliveries,
    required this.createdAt,
  });

  factory DeliveryPartnerAdminModel.fromJson(Map<String, dynamic> json) => DeliveryPartnerAdminModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        vehicleType: json['vehicle_type'] as String? ?? '',
        vehicleNumber: json['vehicle_number'] as String? ?? '',
        licenseNumber: json['license_number'] as String? ?? '',
        status: json['status'] as String? ?? 'offline',
        isVerified: json['is_verified'] as bool? ?? false,
        ratingAvg: _parseDecimal(json['rating_avg']),
        totalDeliveries: _parseInt(json['total_deliveries']),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id,
        fullName,
        phoneNumber,
        vehicleType,
        vehicleNumber,
        licenseNumber,
        status,
        isVerified,
        ratingAvg,
        totalDeliveries,
        createdAt,
      ];
}
