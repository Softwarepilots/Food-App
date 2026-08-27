import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/restaurant_remote_datasource.dart';
import '../../data/models/business_hours_model.dart';
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
    // Watching authProvider (not just reading it) is what makes this
    // provider automatically refetch the moment login/logout changes auth
    // state — without it, this only ever ran once at app startup (before
    // any token existed), and its stale unauthenticated result never
    // refreshed after a successful login, permanently misrouting the app
    // to the "create restaurant" setup screen even for owners who already
    // have one.
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) return null;

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

class BusinessHoursNotifier extends FamilyAsyncNotifier<List<BusinessHoursEntry>, String> {
  @override
  Future<List<BusinessHoursEntry>> build(String restaurantId) {
    return ref.watch(restaurantRemoteDataSourceProvider).getBusinessHours(restaurantId);
  }

  Future<void> save(List<BusinessHoursEntry> entries) async {
    final updated = await ref.read(restaurantRemoteDataSourceProvider).updateBusinessHours(arg, entries);
    state = AsyncValue.data(updated);
  }
}

final businessHoursProvider = AsyncNotifierProvider.family<BusinessHoursNotifier, List<BusinessHoursEntry>, String>(
  BusinessHoursNotifier.new,
);
