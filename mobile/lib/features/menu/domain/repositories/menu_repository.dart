import '../../data/models/food_model.dart';

abstract class MenuRepository {
  Future<RestaurantMenuModel> getRestaurantMenu(String restaurantId);

  Future<List<FoodReviewModel>> getFoodReviews(String foodId);

  Future<FoodReviewModel> submitFoodReview({required String foodId, required int rating, String? comment});
}
