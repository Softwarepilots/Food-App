import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../data/models/order_model.dart';
import 'order_repository_provider.dart';

class OrderListState extends Equatable {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? failure;
  final int page;

  const OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.failure,
    this.page = 1,
  });

  OrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
    int? page,
  }) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [orders, isLoading, isLoadingMore, hasMore, failure, page];
}

class OrderListNotifier extends Notifier<OrderListState> {
  Timer? _pollTimer;

  @override
  OrderListState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    Future.microtask(loadFirstPage);
    return const OrderListState();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref.read(orderRepositoryProvider).getOrders(page: 1);
      state = state.copyWith(orders: result.items, isLoading: false, page: 1, hasMore: result.meta.hasMore);
      _scheduleNextPoll();
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  /// Re-fetches page 1 on a delay, unconditionally — this is what makes a
  /// just-placed order (or an in-flight status change, e.g. a delivery
  /// partner accepting it) show up here without the user pulling to
  /// refresh. Gating this on "any order still active" would miss a brand
  /// new order arriving after the list was last fetched empty/all-settled.
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(AppConstants.orderPollInterval, loadFirstPage);
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await ref.read(orderRepositoryProvider).getOrders(page: nextPage);
      state = state.copyWith(
        orders: [...state.orders, ...result.items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: result.meta.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, failure: Failure.fromException(e));
    }
  }

  Future<void> refresh() => loadFirstPage();
}

final orderListProvider = NotifierProvider<OrderListNotifier, OrderListState>(OrderListNotifier.new);
