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
        return 'Placed';
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

/// Full admin order shape — this is a platform-visibility view (no status
/// transitions), so it carries the restaurant/payment breakdown fields the
/// owner app's [OrderModel] doesn't need, alongside the same core shape.
class AdminOrderModel extends Equatable {
  final String id;
  final String orderNumber;
  final String restaurantName;
  final List<OrderItemModel> items;
  final String customerName;
  final String customerPhone;
  final String deliveryAddressText;
  final OrderStatus status;
  final String paymentStatus;
  final String paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;

  const AdminOrderModel({
    required this.id,
    required this.orderNumber,
    required this.restaurantName,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddressText,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
  });

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) => AdminOrderModel(
        id: json['id'] as String,
        orderNumber: json['order_number'] as String? ?? '',
        restaurantName: json['restaurant_name'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? []).map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>)).toList(),
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String? ?? '',
        deliveryAddressText: json['delivery_address_text'] as String? ?? '',
        status: _parseStatus(json['status'] as String?),
        paymentStatus: json['payment_status'] as String? ?? 'pending',
        paymentMethod: json['payment_method'] as String? ?? 'cod',
        subtotal: _parseDecimal(json['subtotal']),
        deliveryFee: _parseDecimal(json['delivery_fee']),
        taxAmount: _parseDecimal(json['tax_amount']),
        discountAmount: _parseDecimal(json['discount_amount']),
        totalAmount: _parseDecimal(json['total_amount']),
        notes: json['notes'] as String?,
        createdAt: _parseDate(json['created_at']),
        deliveryPartnerName: json['delivery_partner_name'] as String?,
        deliveryPartnerPhone: json['delivery_partner_phone'] as String?,
      );

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        restaurantName,
        items,
        customerName,
        customerPhone,
        deliveryAddressText,
        status,
        paymentStatus,
        paymentMethod,
        subtotal,
        deliveryFee,
        taxAmount,
        discountAmount,
        totalAmount,
        notes,
        createdAt,
        deliveryPartnerName,
        deliveryPartnerPhone,
      ];
}
