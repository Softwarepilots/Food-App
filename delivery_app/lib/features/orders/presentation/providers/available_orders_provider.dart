import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../profile/presentation/providers/partner_provider.dart';
import '../../data/datasources/delivery_order_remote_datasource.dart';
import '../../data/models/order_model.dart';
import 'my_deliveries_provider.dart';

final deliveryOrderRemoteDataSourceProvider = Provider<DeliveryOrderRemoteDataSource>((ref) {
  return DeliveryOrderRemoteDataSource(ref.watch(dioProvider));
});

class AvailableOrdersState extends Equatable {
  final List<OrderModel> orders;
  final bool isLoading;
  final Failure? failure;
  final bool isOnline;

  const AvailableOrdersState({this.orders = const [], this.isLoading = false, this.failure, this.isOnline = false});

  AvailableOrdersState copyWith({List<OrderModel>? orders, bool? isLoading, Failure? failure, bool clearFailure = false}) {
    return AvailableOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isOnline: isOnline,
    );
  }

  @override
  List<Object?> get props => [orders, isLoading, failure, isOnline];
}

/// Polls the job board on an interval, but only while the partner is online —
/// there's no point hitting the network (or showing a spinner) for a rider
/// who can't accept anything right now.
class AvailableOrdersNotifier extends Notifier<AvailableOrdersState> {
  Timer? _timer;

  @override
  AvailableOrdersState build() {
    final profile = ref.watch(myPartnerProfileProvider).valueOrNull;
    final isOnline = profile?.isOnline ?? false;

    ref.onDispose(() => _timer?.cancel());

    if (!isOnline) {
      return const AvailableOrdersState(isOnline: false);
    }

    Future.microtask(refresh);
    _timer = Timer.periodic(AppConstants.availableOrdersPollInterval, (_) => refresh());
    return const AvailableOrdersState(isOnline: true, isLoading: true);
  }

  Future<void> refresh() async {
    if (!state.isOnline) return;
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref.read(deliveryOrderRemoteDataSourceProvider).getAvailableOrders();
      state = state.copyWith(orders: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> accept(String orderId) async {
    await ref.read(deliveryOrderRemoteDataSourceProvider).acceptOrder(orderId);
    // Claimed orders drop off the job board immediately rather than waiting
    // for the next poll tick.
    state = state.copyWith(orders: [for (final order in state.orders) if (order.id != orderId) order]);
    // "My Deliveries" is a separate provider that only fetches on its own
    // load/pull-to-refresh — without this the newly accepted order wouldn't
    // show up there until the rider manually refreshes.
    await ref.read(myDeliveriesProvider.notifier).refresh();
  }
}

final availableOrdersProvider = NotifierProvider<AvailableOrdersNotifier, AvailableOrdersState>(
  AvailableOrdersNotifier.new,
);
