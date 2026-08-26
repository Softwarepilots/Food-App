import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

class RestaurantModel extends Equatable {
  final String id;
  final String name;
  final String coverImageUrl;
  final String addressLine;
  final String city;
  final double averageRating;
  final int totalReviews;
  final bool isActive;
  final bool isAcceptingOrders;
  final String approvalStatus;
  final String displayStatus;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.coverImageUrl,
    required this.addressLine,
    required this.city,
    required this.averageRating,
    required this.totalReviews,
    required this.isActive,
    required this.isAcceptingOrders,
    required this.approvalStatus,
    required this.displayStatus,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) => RestaurantModel(
        id: json['id'] as String,
        name: json['name'] as String,
        coverImageUrl: json['cover_image_url'] as String? ?? '',
        addressLine: json['address_line'] as String? ?? '',
        city: json['city'] as String? ?? '',
        averageRating: _parseDecimal(json['average_rating']),
        totalReviews: json['total_reviews'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        isAcceptingOrders: json['is_accepting_orders'] as bool? ?? true,
        approvalStatus: json['approval_status'] as String? ?? 'pending',
        displayStatus: json['display_status'] as String? ?? 'pending',
      );

  bool get isApproved => approvalStatus == 'approved';

  @override
  List<Object?> get props => [
        id,
        name,
        coverImageUrl,
        addressLine,
        city,
        averageRating,
        totalReviews,
        isActive,
        isAcceptingOrders,
        approvalStatus,
        displayStatus,
      ];
}
