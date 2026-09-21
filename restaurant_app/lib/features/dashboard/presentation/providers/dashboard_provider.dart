import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../restaurant/presentation/providers/restaurant_provider.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/models/dashboard_model.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(ref.watch(dioProvider));
});

class DashboardNotifier extends AsyncNotifier<DashboardModel?> {
  @override
  Future<DashboardModel?> build() async {
    final restaurant = ref.watch(myRestaurantProvider).valueOrNull;
    if (restaurant == null) return null;
    return ref.watch(dashboardRemoteDataSourceProvider).getDashboard(restaurant.id);
  }

  Future<void> refresh() async {
    final restaurant = ref.read(myRestaurantProvider).valueOrNull;
    if (restaurant == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(dashboardRemoteDataSourceProvider).getDashboard(restaurant.id));
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardModel?>(DashboardNotifier.new);
