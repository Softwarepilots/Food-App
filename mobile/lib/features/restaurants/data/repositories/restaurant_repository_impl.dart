import '../../../../core/network/api_response.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../datasources/restaurant_remote_datasource.dart';
import '../models/restaurant_model.dart';

class RestaurantRepositoryImpl implements RestaurantRepository {
  final RestaurantRemoteDataSource _remoteDataSource;

  RestaurantRepositoryImpl(this._remoteDataSource);

  @override
  Future<PaginatedResult<RestaurantModel>> getRestaurants({
    int page = 1,
    String? city,
    String? category,
    String? cuisine,
    String? search,
    double? lat,
    double? lng,
    bool onlyOpen = false,
    String? vegFilter,
  }) {
    return _remoteDataSource.getRestaurants(
      page: page,
      city: city,
      category: category,
      cuisine: cuisine,
      search: search,
      lat: lat,
      lng: lng,
      onlyOpen: onlyOpen,
      vegFilter: vegFilter,
    );
  }

  @override
  Future<RestaurantModel> getRestaurantDetail(String id) => _remoteDataSource.getRestaurantDetail(id);

  @override
  Future<RatingBreakdownModel> getRestaurantRatings(String id) => _remoteDataSource.getRestaurantRatings(id);

  @override
  Future<List<RestaurantCategoryModel>> getCategories() => _remoteDataSource.getCategories();

  @override
  Future<PaginatedResult<RestaurantModel>> getFavorites({int page = 1}) => _remoteDataSource.getFavorites(page: page);

  @override
  Future<bool> setFavorite(String restaurantId, bool isFavorite) =>
      _remoteDataSource.setFavorite(restaurantId, isFavorite);
}
