import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/restaurant_model.dart';

class RestaurantRemoteDataSource {
  final Dio _dio;

  RestaurantRemoteDataSource(this._dio);

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
  }) async {
    try {
      final response = await _dio.get(ApiConstants.restaurants, queryParameters: {
        'page': page,
        if (city != null && city.isNotEmpty) 'city': city,
        if (category != null && category.isNotEmpty) 'category': category,
        if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine,
        if (search != null && search.isNotEmpty) 'search': search,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (onlyOpen) 'only_open': 'true',
        if (vegFilter != null && vegFilter.isNotEmpty) 'veg_filter': vegFilter,
      });
      return PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => RestaurantModel.fromJson(json),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RestaurantModel> getRestaurantDetail(String id) async {
    try {
      final response = await _dio.get(ApiConstants.restaurantDetail(id));
      return RestaurantModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RatingBreakdownModel> getRestaurantRatings(String id) async {
    try {
      final response = await _dio.get(ApiConstants.restaurantRatings(id));
      return RatingBreakdownModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<RestaurantCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get(ApiConstants.restaurantCategories, queryParameters: {'page_size': 50});
      final result = PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => RestaurantCategoryModel.fromJson(json),
      );
      return result.items;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<PaginatedResult<RestaurantModel>> getFavorites({int page = 1}) async {
    try {
      final response = await _dio.get(ApiConstants.favorites, queryParameters: {'page': page});
      return PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => RestaurantModel.fromJson(json),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<bool> setFavorite(String restaurantId, bool isFavorite) async {
    try {
      final response = isFavorite
          ? await _dio.post(ApiConstants.restaurantFavorite(restaurantId))
          : await _dio.delete(ApiConstants.restaurantFavorite(restaurantId));
      final data = unwrapData(response) as Map<String, dynamic>;
      return data['is_favorite'] as bool? ?? isFavorite;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
