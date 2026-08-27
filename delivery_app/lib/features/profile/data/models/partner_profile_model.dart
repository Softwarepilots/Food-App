import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}

enum VehicleType { bicycle, motorcycle, scooter, car }

VehicleType _parseVehicleType(String? value) {
  switch (value) {
    case 'bicycle':
      return VehicleType.bicycle;
    case 'scooter':
      return VehicleType.scooter;
    case 'car':
      return VehicleType.car;
    case 'motorcycle':
    default:
      return VehicleType.motorcycle;
  }
}

extension VehicleTypeX on VehicleType {
  String get apiValue {
    switch (this) {
      case VehicleType.bicycle:
        return 'bicycle';
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.scooter:
        return 'scooter';
      case VehicleType.car:
        return 'car';
    }
  }

  String get label {
    switch (this) {
      case VehicleType.bicycle:
        return 'Bicycle';
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.scooter:
        return 'Scooter';
      case VehicleType.car:
        return 'Car';
    }
  }
}

enum PartnerStatus { offline, online, onDelivery }

PartnerStatus _parsePartnerStatus(String? value) {
  switch (value) {
    case 'online':
      return PartnerStatus.online;
    case 'on_delivery':
      return PartnerStatus.onDelivery;
    case 'offline':
    default:
      return PartnerStatus.offline;
  }
}

extension PartnerStatusX on PartnerStatus {
  String get apiValue {
    switch (this) {
      case PartnerStatus.offline:
        return 'offline';
      case PartnerStatus.online:
        return 'online';
      case PartnerStatus.onDelivery:
        return 'on_delivery';
    }
  }

  String get label {
    switch (this) {
      case PartnerStatus.offline:
        return 'Offline';
      case PartnerStatus.online:
        return 'Online';
      case PartnerStatus.onDelivery:
        return 'On a delivery';
    }
  }
}

class PartnerProfileModel extends Equatable {
  final String id;
  final String fullName;
  final String phoneNumber;
  final VehicleType vehicleType;
  final String vehicleNumber;
  final String licenseNumber;
  final PartnerStatus status;
  final bool isVerified;
  final double ratingAvg;
  final int totalDeliveries;
  final DateTime createdAt;

  const PartnerProfileModel({
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

  factory PartnerProfileModel.fromJson(Map<String, dynamic> json) => PartnerProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        vehicleType: _parseVehicleType(json['vehicle_type'] as String?),
        vehicleNumber: json['vehicle_number'] as String? ?? '',
        licenseNumber: json['license_number'] as String? ?? '',
        status: _parsePartnerStatus(json['status'] as String?),
        isVerified: json['is_verified'] as bool? ?? false,
        ratingAvg: _parseDecimal(json['rating_avg']),
        totalDeliveries: json['total_deliveries'] as int? ?? 0,
        createdAt: _parseDate(json['created_at']),
      );

  bool get isOnline => status == PartnerStatus.online;

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
