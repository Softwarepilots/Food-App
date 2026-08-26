import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/presentation/providers/order_repository_provider.dart';

enum PaymentMethod { cashOnDelivery, online }

extension PaymentMethodX on PaymentMethod {
  String get apiValue => this == PaymentMethod.cashOnDelivery ? 'cod' : 'online';

  String get label => this == PaymentMethod.cashOnDelivery ? 'Cash on Delivery' : 'Pay Online';
}

class CheckoutState extends Equatable {
  final PaymentMethod paymentMethod;
  final String notes;
  final bool isPlacingOrder;
  final Failure? failure;
  final OrderModel? placedOrder;

  const CheckoutState({
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    this.notes = '',
    this.isPlacingOrder = false,
    this.failure,
    this.placedOrder,
  });

  CheckoutState copyWith({
    PaymentMethod? paymentMethod,
    String? notes,
    bool? isPlacingOrder,
    Failure? failure,
    bool clearFailure = false,
    OrderModel? placedOrder,
  }) {
    return CheckoutState(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      failure: clearFailure ? null : (failure ?? this.failure),
      placedOrder: placedOrder ?? this.placedOrder,
    );
  }

  @override
  List<Object?> get props => [paymentMethod, notes, isPlacingOrder, failure, placedOrder];
}

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  List<Map<String, dynamic>> _itemsPayload(List<CartItemModel> items) {
    return items
        .map((item) => {
              'food_id': item.food.id,
              if (item.variant != null) 'variant_id': item.variant!.id,
              'addon_quantities': item.addonQuantities,
              'quantity': item.quantity,
              if (item.notes.isNotEmpty) 'notes': item.notes,
            })
        .toList();
  }

  /// Places the order from the current cart against [addressId], then
  /// clears the cart on success. Returns the created order.
  Future<OrderModel> placeOrder({required String addressId}) async {
    final cart = ref.read(cartProvider);
    state = state.copyWith(isPlacingOrder: true, clearFailure: true);
    try {
      final order = await ref.read(orderRepositoryProvider).createOrder(
            restaurantId: cart.restaurantId!,
            addressId: addressId,
            items: _itemsPayload(cart.items),
            paymentMethod: state.paymentMethod.apiValue,
            notes: state.notes,
          );
      ref.read(cartProvider.notifier).clear();
      state = state.copyWith(isPlacingOrder: false, placedOrder: order);
      return order;
    } catch (e) {
      state = state.copyWith(isPlacingOrder: false, failure: Failure.fromException(e));
      rethrow;
    }
  }
}

final checkoutProvider = NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);
