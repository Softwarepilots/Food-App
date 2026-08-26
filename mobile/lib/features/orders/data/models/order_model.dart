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

/// The set of statuses an order can move through, matching the backend's
/// `Order.status` choices field.
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
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Order placed';
      case OrderStatus.accepted:
        return 'Accepted by restaurant';
      case OrderStatus.preparing:
        return 'Preparing your food';
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

  bool get isCancelled => this == OrderStatus.cancelled;
  bool get isDelivered => this == OrderStatus.delivered;
  bool get isActive => !isCancelled && !isDelivered;

  static const List<OrderStatus> timeline = [
    OrderStatus.placed,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.readyForPickup,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  int get stepIndex => timeline.indexOf(this);
}

class OrderItemModel extends Equatable {
  final String id;
  final String foodName;
  final String? variantName;
  final List<String> addonNames;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.foodName,
    this.variantName,
    this.addonNames = const [],
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['id'] as String,
        foodName: json['food_name'] as String? ?? '',
        variantName: json['variant_name'] as String?,
        addonNames: (json['addon_names'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        quantity: json['quantity'] as int? ?? 1,
        unitPrice: _parseDecimal(json['unit_price']),
        lineTotal: _parseDecimal(json['line_total']),
        notes: json['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, foodName, variantName, addonNames, quantity, unitPrice, lineTotal, notes];
}

class OrderModel extends Equatable {
  final String id;
  final String orderNumber;
  final String restaurantId;
  final String restaurantName;
  final String? restaurantImageUrl;
  final List<OrderItemModel> items;
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
  final DateTime? estimatedDeliveryAt;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantImageUrl,
    required this.items,
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
    this.estimatedDeliveryAt,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] as String,
        orderNumber: json['order_number'] as String? ?? (json['id'] as String).substring(0, 8).toUpperCase(),
        restaurantId: json['restaurant_id'] as String? ?? json['restaurant']?['id'] as String? ?? '',
        restaurantName: json['restaurant_name'] as String? ?? json['restaurant']?['name'] as String? ?? '',
        restaurantImageUrl: json['restaurant_image_url'] as String?,
        items: (json['items'] as List<dynamic>? ?? []).map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>)).toList(),
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
        estimatedDeliveryAt: json['estimated_delivery_at'] != null ? _parseDate(json['estimated_delivery_at']) : null,
        deliveryPartnerName: json['delivery_partner_name'] as String?,
        deliveryPartnerPhone: json['delivery_partner_phone'] as String?,
      );

  bool get canCancel => status == OrderStatus.placed || status == OrderStatus.accepted;

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        restaurantId,
        restaurantName,
        restaurantImageUrl,
        items,
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
        estimatedDeliveryAt,
        deliveryPartnerName,
        deliveryPartnerPhone,
      ];
}
