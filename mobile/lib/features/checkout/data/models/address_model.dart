import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

class AddressModel extends Equatable {
  final String id;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        addressLine1: json['address_line1'] as String? ?? '',
        addressLine2: json['address_line2'] as String?,
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        latitude: _parseDecimal(json['latitude']),
        longitude: _parseDecimal(json['longitude']),
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'address_line1': addressLine1,
        if (addressLine2 != null && addressLine2!.isNotEmpty) 'address_line2': addressLine2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get fullAddress => [
        addressLine1,
        if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
        city,
        state,
        pincode,
      ].join(', ');

  @override
  List<Object?> get props =>
      [id, label, addressLine1, addressLine2, city, state, pincode, latitude, longitude, isDefault];
}
