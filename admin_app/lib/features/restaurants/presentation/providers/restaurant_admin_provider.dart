import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/restaurant_admin_remote_datasource.dart';
import '../../data/models/restaurant_admin_model.dart';

final restaurantAdminRemoteDataSourceProvider = Provider<RestaurantAdminRemoteDataSource>((ref) {
  return RestaurantAdminRemoteDataSource(ref.watch(dioProvider));
});

/// `null` means "All" — no `approval_status` filter is sent to the API.
enum RestaurantApprovalFilter { all, pending, approved, rejected }

extension RestaurantApprovalFilterX on RestaurantApprovalFilter {
  String? get apiValue {
    switch (this) {
      case RestaurantApprovalFilter.all:
        return null;
      case RestaurantApprovalFilter.pending:
        return 'pending';
      case RestaurantApprovalFilter.approved:
        return 'approved';
      case RestaurantApprovalFilter.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case RestaurantApprovalFilter.all:
        return 'All';
      case RestaurantApprovalFilter.pending:
        return 'Pending';
      case RestaurantApprovalFilter.approved:
        return 'Approved';
      case RestaurantApprovalFilter.rejected:
        return 'Rejected';
    }
  }
}

class RestaurantAdminListState extends Equatable {
  final List<RestaurantAdminModel> restaurants;
  final RestaurantApprovalFilter filter;
  final bool isLoading;
  final Failure? failure;

  const RestaurantAdminListState({
    this.restaurants = const [],
    this.filter = RestaurantApprovalFilter.all,
    this.isLoading = false,
    this.failure,
  });

  RestaurantAdminListState copyWith({
    List<RestaurantAdminModel>? restaurants,
    RestaurantApprovalFilter? filter,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RestaurantAdminListState(
      restaurants: restaurants ?? this.restaurants,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [restaurants, filter, isLoading, failure];
}

class RestaurantAdminListNotifier extends Notifier<RestaurantAdminListState> {
  @override
  RestaurantAdminListState build() {
    Future.microtask(refresh);
    return const RestaurantAdminListState(isLoading: true);
  }

  Future<void> setFilter(RestaurantApprovalFilter filter) async {
    state = state.copyWith(filter: filter);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref
          .read(restaurantAdminRemoteDataSourceProvider)
          .getRestaurants(approvalStatus: state.filter.apiValue);
      state = state.copyWith(restaurants: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> approve(String restaurantId) async {
    final updated = await ref.read(restaurantAdminRemoteDataSourceProvider).approve(restaurantId);
    _replace(updated);
  }

  Future<void> reject(String restaurantId, String reason) async {
    final updated = await ref.read(restaurantAdminRemoteDataSourceProvider).reject(restaurantId, reason);
    _replace(updated);
  }

  void _replace(RestaurantAdminModel updated) {
    // If the current filter no longer matches the updated status (e.g. an
    // approved restaurant while viewing "Pending"), drop it from the list
    // instead of leaving a stale row; otherwise swap it in place.
    final filterValue = state.filter.apiValue;
    final stillMatches = filterValue == null || updated.approvalStatus == filterValue;
    state = state.copyWith(
      restaurants: stillMatches
          ? [for (final r in state.restaurants) if (r.id == updated.id) updated else r]
          : [for (final r in state.restaurants) if (r.id != updated.id) r],
    );
  }
}

final restaurantAdminListProvider = NotifierProvider<RestaurantAdminListNotifier, RestaurantAdminListState>(
  RestaurantAdminListNotifier.new,
);
