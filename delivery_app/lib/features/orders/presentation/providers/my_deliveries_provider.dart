import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../data/models/order_model.dart';
import 'available_orders_provider.dart';

class MyDeliveriesState extends Equatable {
  final List<OrderModel> orders;
  final bool isLoading;
  final Failure? failure;

  const MyDeliveriesState({this.orders = const [], this.isLoading = false, this.failure});

  MyDeliveriesState copyWith({List<OrderModel>? orders, bool? isLoading, Failure? failure, bool clearFailure = false}) {
    return MyDeliveriesState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [orders, isLoading, failure];
}

/// Fetches the partner's own assigned orders (unfiltered — the screen splits
/// active vs. history client-side via `status.isActive`, mirroring the
/// restaurant app's order tabs). Refreshed on load and pull-to-refresh; no
/// polling needed since the partner drives these transitions themselves.
class MyDeliveriesNotifier extends Notifier<MyDeliveriesState> {
  @override
  MyDeliveriesState build() {
    Future.microtask(refresh);
    return const MyDeliveriesState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref.read(deliveryOrderRemoteDataSourceProvider).getMyDeliveries();
      state = state.copyWith(orders: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> markDelivered(String orderId) async {
    final updated = await ref.read(deliveryOrderRemoteDataSourceProvider).markDelivered(orderId);
    state = state.copyWith(
      orders: [for (final order in state.orders) if (order.id == orderId) updated else order],
    );
  }
}

final myDeliveriesProvider = NotifierProvider<MyDeliveriesNotifier, MyDeliveriesState>(MyDeliveriesNotifier.new);
