import '../../../../core/network/api_response.dart';
import '../../data/models/restaurant_model.dart';

abstract class RestaurantRepository {
  Future<PaginatedResult<RestaurantModel>> getRestaurants({
    int page = 1,
    String? city,
    String? category,
    String? cuisine,
    String? search,
    double? lat,
    double? lng,
    bool onlyOpen = false,
  });

  Future<RestaurantModel> getRestaurantDetail(String id);

  Future<RatingBreakdownModel> getRestaurantRatings(String id);

  Future<List<RestaurantCategoryModel>> getCategories();

  Future<PaginatedResult<RestaurantModel>> getFavorites({int page = 1});

  Future<bool> setFavorite(String restaurantId, bool isFavorite);
}
