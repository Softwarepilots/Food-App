import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/restaurant_model.dart';
import 'restaurant_repository_provider.dart';

final restaurantDetailProvider = FutureProvider.family<RestaurantModel, String>((ref, id) {
  return ref.watch(restaurantRepositoryProvider).getRestaurantDetail(id);
});

final restaurantRatingsProvider = FutureProvider.family<RatingBreakdownModel, String>((ref, id) {
  return ref.watch(restaurantRepositoryProvider).getRestaurantRatings(id);
});
