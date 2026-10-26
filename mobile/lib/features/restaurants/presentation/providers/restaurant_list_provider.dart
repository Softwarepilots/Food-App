import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../data/models/restaurant_model.dart';
import 'restaurant_repository_provider.dart';

class RestaurantListFilters extends Equatable {
  final String? search;
  final String? category;
  final String? cuisine;
  final String? city;
  final double? lat;
  final double? lng;
  final bool onlyOpen;
  final String? vegFilter;

  const RestaurantListFilters({
    this.search,
    this.category,
    this.cuisine,
    this.city,
    this.lat,
    this.lng,
    this.onlyOpen = false,
    this.vegFilter,
  });

  RestaurantListFilters copyWith({
    String? search,
    String? category,
    String? cuisine,
    String? city,
    double? lat,
    double? lng,
    bool? onlyOpen,
    String? vegFilter,
  }) {
    return RestaurantListFilters(
      search: search ?? this.search,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      onlyOpen: onlyOpen ?? this.onlyOpen,
      vegFilter: vegFilter ?? this.vegFilter,
    );
  }

  @override
  List<Object?> get props => [search, category, cuisine, city, lat, lng, onlyOpen, vegFilter];
}

class RestaurantListState extends Equatable {
  final List<RestaurantModel> restaurants;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? failure;
  final int page;
  final RestaurantListFilters filters;

  const RestaurantListState({
    this.restaurants = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.failure,
    this.page = 1,
    this.filters = const RestaurantListFilters(),
  });

  RestaurantListState copyWith({
    List<RestaurantModel>? restaurants,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
    int? page,
    RestaurantListFilters? filters,
  }) {
    return RestaurantListState(
      restaurants: restaurants ?? this.restaurants,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      page: page ?? this.page,
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props => [restaurants, isLoading, isLoadingMore, hasMore, failure, page, filters];
}

class RestaurantListNotifier extends Notifier<RestaurantListState> {
  @override
  RestaurantListState build() {
    Future.microtask(loadFirstPage);
    return const RestaurantListState();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref.read(restaurantRepositoryProvider).getRestaurants(
            page: 1,
            search: state.filters.search,
            category: state.filters.category,
            cuisine: state.filters.cuisine,
            city: state.filters.city,
            lat: state.filters.lat,
            lng: state.filters.lng,
            onlyOpen: state.filters.onlyOpen,
            vegFilter: state.filters.vegFilter,
          );
      state = state.copyWith(
        restaurants: result.items,
        isLoading: false,
        page: 1,
        hasMore: result.meta.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await ref.read(restaurantRepositoryProvider).getRestaurants(
            page: nextPage,
            search: state.filters.search,
            category: state.filters.category,
            cuisine: state.filters.cuisine,
            city: state.filters.city,
            lat: state.filters.lat,
            lng: state.filters.lng,
            onlyOpen: state.filters.onlyOpen,
            vegFilter: state.filters.vegFilter,
          );
      state = state.copyWith(
        restaurants: [...state.restaurants, ...result.items],
        isLoadingMore: false,
        page: nextPage,
        hasMore: result.meta.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, failure: Failure.fromException(e));
    }
  }

  Future<void> updateFilters(RestaurantListFilters filters) async {
    state = state.copyWith(filters: filters);
    await loadFirstPage();
  }

  Future<void> refresh() => loadFirstPage();

  /// Optimistically flips the card's heart, then confirms with the server —
  /// reverts locally if the request fails.
  Future<void> toggleFavorite(String restaurantId) async {
    final index = state.restaurants.indexWhere((r) => r.id == restaurantId);
    if (index == -1) return;
    final current = state.restaurants[index];
    final optimistic = [...state.restaurants];
    optimistic[index] = current.copyWith(isFavorite: !current.isFavorite);
    state = state.copyWith(restaurants: optimistic);

    try {
      await ref.read(restaurantRepositoryProvider).setFavorite(restaurantId, !current.isFavorite);
    } catch (_) {
      final reverted = [...state.restaurants];
      final revertIndex = reverted.indexWhere((r) => r.id == restaurantId);
      if (revertIndex != -1) reverted[revertIndex] = current;
      state = state.copyWith(restaurants: reverted);
    }
  }
}

final restaurantListProvider = NotifierProvider<RestaurantListNotifier, RestaurantListState>(
  RestaurantListNotifier.new,
);
