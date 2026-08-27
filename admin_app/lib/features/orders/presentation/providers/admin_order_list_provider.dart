import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/admin_order_remote_datasource.dart';
import '../../data/models/admin_order_model.dart';

final adminOrderRemoteDataSourceProvider = Provider<AdminOrderRemoteDataSource>((ref) {
  return AdminOrderRemoteDataSource(ref.watch(dioProvider));
});

/// `null` means "All statuses".
const List<OrderStatus?> orderStatusFilters = [
  null,
  OrderStatus.placed,
  OrderStatus.accepted,
  OrderStatus.preparing,
  OrderStatus.readyForPickup,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
  OrderStatus.cancelled,
];

String orderStatusFilterLabel(OrderStatus? status) => status == null ? 'All' : status.label;

class AdminOrderListState extends Equatable {
  final List<AdminOrderModel> orders;
  final OrderStatus? statusFilter;
  final bool isLoading;
  final Failure? failure;

  const AdminOrderListState({this.orders = const [], this.statusFilter, this.isLoading = false, this.failure});

  AdminOrderListState copyWith({
    List<AdminOrderModel>? orders,
    OrderStatus? statusFilter,
    bool clearStatusFilter = false,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AdminOrderListState(
      orders: orders ?? this.orders,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [orders, statusFilter, isLoading, failure];
}

class AdminOrderListNotifier extends Notifier<AdminOrderListState> {
  @override
  AdminOrderListState build() {
    Future.microtask(refresh);
    return const AdminOrderListState(isLoading: true);
  }

  Future<void> setStatusFilter(OrderStatus? status) async {
    state = state.copyWith(statusFilter: status, clearStatusFilter: status == null);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref
          .read(adminOrderRemoteDataSourceProvider)
          .getOrders(status: state.statusFilter?.apiValue);
      state = state.copyWith(orders: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }
}

final adminOrderListProvider = NotifierProvider<AdminOrderListNotifier, AdminOrderListState>(
  AdminOrderListNotifier.new,
);
