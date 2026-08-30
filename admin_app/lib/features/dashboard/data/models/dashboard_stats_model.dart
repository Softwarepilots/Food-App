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

class UserStats extends Equatable {
  final int customer;
  final int restaurantOwner;
  final int deliveryPartner;
  final int admin;
  final int total;

  const UserStats({
    required this.customer,
    required this.restaurantOwner,
    required this.deliveryPartner,
    required this.admin,
    required this.total,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        customer: _parseInt(json['customer']),
        restaurantOwner: _parseInt(json['restaurant_owner']),
        deliveryPartner: _parseInt(json['delivery_partner']),
        admin: _parseInt(json['admin']),
        total: _parseInt(json['total']),
      );

  @override
  List<Object?> get props => [customer, restaurantOwner, deliveryPartner, admin, total];
}

class RestaurantStats extends Equatable {
  final int pending;
  final int approved;
  final int rejected;
  final int total;

  const RestaurantStats({required this.pending, required this.approved, required this.rejected, required this.total});

  factory RestaurantStats.fromJson(Map<String, dynamic> json) => RestaurantStats(
        pending: _parseInt(json['pending']),
        approved: _parseInt(json['approved']),
        rejected: _parseInt(json['rejected']),
        total: _parseInt(json['total']),
      );

  @override
  List<Object?> get props => [pending, approved, rejected, total];
}

class OrderStats extends Equatable {
  final int active;
  final int todayCount;
  final double todayRevenue;
  final int total;

  const OrderStats({required this.active, required this.todayCount, required this.todayRevenue, required this.total});

  factory OrderStats.fromJson(Map<String, dynamic> json) => OrderStats(
        active: _parseInt(json['active']),
        todayCount: _parseInt(json['today_count']),
        todayRevenue: _parseDecimal(json['today_revenue']),
        total: _parseInt(json['total']),
      );

  @override
  List<Object?> get props => [active, todayCount, todayRevenue, total];
}

class DeliveryStats extends Equatable {
  final int online;
  final int unverified;
  final int total;

  const DeliveryStats({required this.online, required this.unverified, required this.total});

  factory DeliveryStats.fromJson(Map<String, dynamic> json) => DeliveryStats(
        online: _parseInt(json['online']),
        unverified: _parseInt(json['unverified']),
        total: _parseInt(json['total']),
      );

  @override
  List<Object?> get props => [online, unverified, total];
}

class DashboardStatsModel extends Equatable {
  final UserStats users;
  final RestaurantStats restaurants;
  final OrderStats orders;
  final DeliveryStats delivery;

  const DashboardStatsModel({
    required this.users,
    required this.restaurants,
    required this.orders,
    required this.delivery,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) => DashboardStatsModel(
        users: UserStats.fromJson(json['users'] as Map<String, dynamic>? ?? const {}),
        restaurants: RestaurantStats.fromJson(json['restaurants'] as Map<String, dynamic>? ?? const {}),
        orders: OrderStats.fromJson(json['orders'] as Map<String, dynamic>? ?? const {}),
        delivery: DeliveryStats.fromJson(json['delivery'] as Map<String, dynamic>? ?? const {}),
      );

  @override
  List<Object?> get props => [users, restaurants, orders, delivery];
}
