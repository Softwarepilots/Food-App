import 'package:equatable/equatable.dart';

/// Partial restaurant model for the admin dashboard's restaurant table — it
/// intentionally ignores nested fields (images, business_hours, cuisine_tags,
/// etc.) the table doesn't render; those are safely dropped by `fromJson`.
class RestaurantAdminModel extends Equatable {
  final String id;
  final String name;
  final String city;
  final String approvalStatus;
  final String rejectionReason;
  final bool isActive;
  final bool isAcceptingOrders;

  const RestaurantAdminModel({
    required this.id,
    required this.name,
    required this.city,
    required this.approvalStatus,
    required this.rejectionReason,
    required this.isActive,
    required this.isAcceptingOrders,
  });

  factory RestaurantAdminModel.fromJson(Map<String, dynamic> json) => RestaurantAdminModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        approvalStatus: json['approval_status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        isAcceptingOrders: json['is_accepting_orders'] as bool? ?? true,
      );

  bool get isPending => approvalStatus == 'pending';

  @override
  List<Object?> get props => [id, name, city, approvalStatus, rejectionReason, isActive, isAcceptingOrders];
}
