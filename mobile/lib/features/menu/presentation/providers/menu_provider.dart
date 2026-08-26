import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/menu_remote_datasource.dart';
import '../../data/models/food_model.dart';
import '../../data/repositories/menu_repository_impl.dart';
import '../../domain/repositories/menu_repository.dart';

final menuRemoteDataSourceProvider = Provider<MenuRemoteDataSource>((ref) {
  return MenuRemoteDataSource(ref.watch(dioProvider));
});

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepositoryImpl(ref.watch(menuRemoteDataSourceProvider));
});

final restaurantMenuProvider = FutureProvider.family<RestaurantMenuModel, String>((ref, restaurantId) {
  return ref.watch(menuRepositoryProvider).getRestaurantMenu(restaurantId);
});

final foodReviewsProvider = FutureProvider.family<List<FoodReviewModel>, String>((ref, foodId) {
  return ref.watch(menuRepositoryProvider).getFoodReviews(foodId);
});
