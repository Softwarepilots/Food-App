import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../data/models/order_model.dart';

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource(ref.watch(dioProvider));
});

class OrderListState extends Equatable {
  final List<OrderModel> orders;
  final bool isLoading;
  final Failure? failure;

  const OrderListState({this.orders = const [], this.isLoading = false, this.failure});

  OrderListState copyWith({List<OrderModel>? orders, bool? isLoading, Failure? failure, bool clearFailure = false}) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [orders, isLoading, failure];
}

/// Polls the owner's incoming orders on an interval so new orders and
/// customer cancellations show up without a manual pull-to-refresh.
class OrderListNotifier extends Notifier<OrderListState> {
  @override
  OrderListState build() {
    Future.microtask(refresh);
    return const OrderListState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref.read(orderRemoteDataSourceProvider).getRestaurantOrders();
      state = state.copyWith(orders: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> advanceStatus(String orderId, OrderStatus newStatus) async {
    final updated = await ref.read(orderRemoteDataSourceProvider).updateStatus(orderId, newStatus);
    state = state.copyWith(
      orders: [for (final order in state.orders) if (order.id == orderId) updated else order],
    );
  }
}

final orderListProvider = NotifierProvider<OrderListNotifier, OrderListState>(OrderListNotifier.new);
