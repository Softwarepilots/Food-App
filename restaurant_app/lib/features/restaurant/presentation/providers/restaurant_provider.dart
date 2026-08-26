import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/restaurant_remote_datasource.dart';
import '../../data/models/restaurant_model.dart';

final restaurantRemoteDataSourceProvider = Provider<RestaurantRemoteDataSource>((ref) {
  return RestaurantRemoteDataSource(ref.watch(dioProvider));
});

/// The owner app assumes a single managed restaurant — the first one
/// returned by `/restaurants/mine/`. Multi-restaurant owners aren't
/// supported yet; this is the seam to extend if that's ever needed.
class MyRestaurantNotifier extends AsyncNotifier<RestaurantModel?> {
  @override
  Future<RestaurantModel?> build() async {
    final restaurants = await ref.watch(restaurantRemoteDataSourceProvider).getMyRestaurants();
    return restaurants.isEmpty ? null : restaurants.first;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final restaurants = await ref.read(restaurantRemoteDataSourceProvider).getMyRestaurants();
      return restaurants.isEmpty ? null : restaurants.first;
    });
  }

  Future<void> createRestaurant({
    required String name,
    required String description,
    required String addressLine,
    required String city,
    required double latitude,
    required double longitude,
  }) async {
    final restaurant = await ref.read(restaurantRemoteDataSourceProvider).createRestaurant(
          name: name,
          description: description,
          addressLine: addressLine,
          city: city,
          latitude: latitude,
          longitude: longitude,
        );
    state = AsyncValue.data(restaurant);
  }

  Future<void> setAcceptingOrders(bool isAcceptingOrders) async {
    final current = state.value;
    if (current == null) return;
    final updated = await ref
        .read(restaurantRemoteDataSourceProvider)
        .updateStatus(restaurantId: current.id, isAcceptingOrders: isAcceptingOrders);
    state = AsyncValue.data(updated);
  }
}

final myRestaurantProvider = AsyncNotifierProvider<MyRestaurantNotifier, RestaurantModel?>(MyRestaurantNotifier.new);
