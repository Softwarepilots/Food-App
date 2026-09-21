import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

/// Today's order/sales summary for the partner dashboard (`GET
/// /restaurants/{id}/dashboard/`). `todaySales`/`averageOrderValue` are
/// null for STAFF-role callers — the backend omits financial figures for
/// that role rather than sending zeros, so `null` here means "not visible
/// to you", not "no sales yet".
class DashboardModel extends Equatable {
  final String restaurantName;
  final String displayStatus;
  final int todayOrdersCount;
  final int pendingOrdersCount;
  final int completedOrdersCount;
  final double cancellationRatePercent;
  final double rating;
  final double? todaySales;
  final double? averageOrderValue;

  const DashboardModel({
    required this.restaurantName,
    required this.displayStatus,
    required this.todayOrdersCount,
    required this.pendingOrdersCount,
    required this.completedOrdersCount,
    required this.cancellationRatePercent,
    required this.rating,
    this.todaySales,
    this.averageOrderValue,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) => DashboardModel(
        restaurantName: json['restaurant_name'] as String? ?? '',
        displayStatus: json['display_status'] as String? ?? 'open',
        todayOrdersCount: json['today_orders_count'] as int? ?? 0,
        pendingOrdersCount: json['pending_orders_count'] as int? ?? 0,
        completedOrdersCount: json['completed_orders_count'] as int? ?? 0,
        cancellationRatePercent: _parseDecimal(json['cancellation_rate_percent']),
        rating: _parseDecimal(json['rating']),
        todaySales: json['today_sales'] != null ? _parseDecimal(json['today_sales']) : null,
        averageOrderValue: json['average_order_value'] != null ? _parseDecimal(json['average_order_value']) : null,
      );

  @override
  List<Object?> get props => [
        restaurantName,
        displayStatus,
        todayOrdersCount,
        pendingOrdersCount,
        completedOrdersCount,
        cancellationRatePercent,
        rating,
        todaySales,
        averageOrderValue,
      ];
}
