import '../../domain/repositories/menu_repository.dart';
import '../datasources/menu_remote_datasource.dart';
import '../models/food_model.dart';

class MenuRepositoryImpl implements MenuRepository {
  final MenuRemoteDataSource _remoteDataSource;

  MenuRepositoryImpl(this._remoteDataSource);

  @override
  Future<RestaurantMenuModel> getRestaurantMenu(String restaurantId) => _remoteDataSource.getRestaurantMenu(restaurantId);

  @override
  Future<List<FoodReviewModel>> getFoodReviews(String foodId) => _remoteDataSource.getFoodReviews(foodId);

  @override
  Future<FoodReviewModel> submitFoodReview({required String foodId, required int rating, String? comment}) {
    return _remoteDataSource.submitFoodReview(foodId: foodId, rating: rating, comment: comment);
  }
}
