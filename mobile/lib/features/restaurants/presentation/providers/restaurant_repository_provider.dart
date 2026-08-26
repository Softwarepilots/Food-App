import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/restaurant_remote_datasource.dart';
import '../../data/repositories/restaurant_repository_impl.dart';
import '../../domain/repositories/restaurant_repository.dart';

final restaurantRemoteDataSourceProvider = Provider<RestaurantRemoteDataSource>((ref) {
  return RestaurantRemoteDataSource(ref.watch(dioProvider));
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepositoryImpl(ref.watch(restaurantRemoteDataSourceProvider));
});

final restaurantCategoriesProvider = FutureProvider((ref) {
  return ref.watch(restaurantRepositoryProvider).getCategories();
});

final favoritesProvider = FutureProvider((ref) async {
  final result = await ref.watch(restaurantRepositoryProvider).getFavorites();
  return result.items;
});
