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

enum OrderStatus { placed, accepted, preparing, readyForPickup, outForDelivery, delivered, cancelled }

OrderStatus _parseStatus(String? value) {
  switch (value) {
    case 'accepted':
      return OrderStatus.accepted;
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready_for_pickup':
      return OrderStatus.readyForPickup;
    case 'out_for_delivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'placed':
    default:
      return OrderStatus.placed;
  }
}

extension OrderStatusX on OrderStatus {
  String get apiValue {
    switch (this) {
      case OrderStatus.placed:
        return 'placed';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'New order';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for pickup';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this != OrderStatus.delivered && this != OrderStatus.cancelled;

  /// The single next status this owner app lets you move to (mirrors the
  /// backend's `ALLOWED_STATUS_TRANSITIONS`) — null when there's no forward
  /// move (delivered/cancelled) or the next step is customer/delivery-partner-driven.
  /// Once an order is ready for pickup, claiming and delivering it belongs to
  /// the delivery partner app, not this one.
  OrderStatus? get nextStep {
    switch (this) {
      case OrderStatus.placed:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.readyForPickup;
      case OrderStatus.readyForPickup:
      case OrderStatus.outForDelivery:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return null;
    }
  }
}

class OrderItemModel extends Equatable {
  final String foodName;
  final String? variantName;
  final List<String> addonNames;
  final int quantity;
  final double lineTotal;
  final String? notes;

  const OrderItemModel({
    required this.foodName,
    this.variantName,
    this.addonNames = const [],
    required this.quantity,
    required this.lineTotal,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        foodName: json['food_name'] as String? ?? '',
        variantName: json['variant_name'] as String?,
        addonNames: (json['addon_names'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        quantity: json['quantity'] as int? ?? 1,
        lineTotal: _parseDecimal(json['line_total']),
        notes: json['notes'] as String?,
      );

  @override
  List<Object?> get props => [foodName, variantName, addonNames, quantity, lineTotal, notes];
}

class OrderModel extends Equatable {
  final String id;
  final String orderNumber;
  final List<OrderItemModel> items;
  final String customerName;
  final String customerPhone;
  final String deliveryAddressText;
  final OrderStatus status;
  final String paymentStatus;
  final String paymentMethod;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddressText,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] as String,
        orderNumber: json['order_number'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? []).map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>)).toList(),
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String? ?? '',
        deliveryAddressText: json['delivery_address_text'] as String? ?? '',
        status: _parseStatus(json['status'] as String?),
        paymentStatus: json['payment_status'] as String? ?? 'pending',
        paymentMethod: json['payment_method'] as String? ?? 'cod',
        totalAmount: _parseDecimal(json['total_amount']),
        notes: json['notes'] as String?,
        createdAt: _parseDate(json['created_at']),
      );

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        items,
        customerName,
        customerPhone,
        deliveryAddressText,
        status,
        paymentStatus,
        paymentMethod,
        totalAmount,
        notes,
        createdAt,
      ];
}
