import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/food_model.dart';

class MenuRemoteDataSource {
  final Dio _dio;

  MenuRemoteDataSource(this._dio);

  Future<List<FoodModel>> getFoods(String restaurantId) async {
    try {
      final response = await _dio.get(ApiConstants.foods(restaurantId), queryParameters: {'page_size': 100});
      final result = PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => FoodModel.fromJson(json));
      return result.items;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<FoodModel> createFood({
    required String restaurantId,
    required String name,
    required double basePrice,
    required String foodType,
    String description = '',
  }) async {
    try {
      final response = await _dio.post(ApiConstants.foods(restaurantId), data: {
        'name': name,
        'base_price': basePrice,
        'food_type': foodType,
        'description': description,
      });
      return FoodModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<FoodModel> setAvailability({required String restaurantId, required String foodId, required bool isAvailable}) async {
    try {
      final response = await _dio.patch(
        ApiConstants.foodAvailability(restaurantId, foodId),
        data: {'is_available': isAvailable},
      );
      return FoodModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
