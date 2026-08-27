import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/models/dashboard_stats_model.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(ref.watch(dioProvider));
});

class DashboardStatsNotifier extends AsyncNotifier<DashboardStatsModel> {
  @override
  Future<DashboardStatsModel> build() {
    return ref.watch(dashboardRemoteDataSourceProvider).getStats();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(dashboardRemoteDataSourceProvider).getStats());
  }
}

final dashboardStatsProvider = AsyncNotifierProvider<DashboardStatsNotifier, DashboardStatsModel>(
  DashboardStatsNotifier.new,
);
