import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import 'order_repository_provider.dart';

/// Polls the order detail endpoint every [AppConstants.orderPollInterval]
/// while the order is still active (not delivered/cancelled), so the
/// tracking screen reflects status changes without the user refreshing.
class OrderDetailNotifier extends FamilyNotifier<AsyncValue<OrderModel>, String> {
  Timer? _pollTimer;

  @override
  AsyncValue<OrderModel> build(String arg) {
    ref.onDispose(() => _pollTimer?.cancel());
    _fetch(arg);
    return const AsyncValue.loading();
  }

  Future<void> _fetch(String orderId) async {
    try {
      final order = await ref.read(orderRepositoryProvider).getOrderDetail(orderId);
      state = AsyncValue.data(order);
      _pollTimer?.cancel();
      if (order.status.isActive) {
        _pollTimer = Timer(AppConstants.orderPollInterval, () => _fetch(orderId));
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() => _fetch(arg);

  Future<void> cancelOrder({String? reason}) async {
    final cancelled = await ref.read(orderRepositoryProvider).cancelOrder(arg, reason: reason);
    _pollTimer?.cancel();
    state = AsyncValue.data(cancelled);
  }
}

final orderDetailProvider = NotifierProvider.family<OrderDetailNotifier, AsyncValue<OrderModel>, String>(
  OrderDetailNotifier.new,
);
