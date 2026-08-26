import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/food_model.dart';

class MenuRemoteDataSource {
  final Dio _dio;

  MenuRemoteDataSource(this._dio);

  Future<RestaurantMenuModel> getRestaurantMenu(String restaurantId) async {
    try {
      final response = await _dio.get(ApiConstants.publicMenu(restaurantId));
      return RestaurantMenuModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<FoodReviewModel>> getFoodReviews(String foodId) async {
    try {
      final response = await _dio.get(ApiConstants.foodReviews(foodId));
      final data = unwrapData(response) as List<dynamic>;
      return data.map((e) => FoodReviewModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<FoodReviewModel> submitFoodReview({
    required String foodId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.foodReviews(foodId), data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return FoodReviewModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
