import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/business_hours_model.dart';
import '../models/restaurant_model.dart';

class RestaurantRemoteDataSource {
  final Dio _dio;

  RestaurantRemoteDataSource(this._dio);

  Future<List<RestaurantModel>> getMyRestaurants() async {
    try {
      final response = await _dio.get(ApiConstants.myRestaurants, queryParameters: {'page_size': 20});
      final result = PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => RestaurantModel.fromJson(json));
      return result.items;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RestaurantModel> createRestaurant({
    required String name,
    required String description,
    required String addressLine,
    required String city,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.restaurants, data: {
        'name': name,
        'description': description,
        'address_line': addressLine,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      });
      return RestaurantModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RestaurantModel> updateStatus({
    required String restaurantId,
    bool? isActive,
    bool? isAcceptingOrders,
  }) async {
    try {
      final response = await _dio.patch(ApiConstants.restaurantStatus(restaurantId), data: {
        if (isActive != null) 'is_active': isActive,
        if (isAcceptingOrders != null) 'is_accepting_orders': isAcceptingOrders,
      });
      return RestaurantModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BusinessHoursEntry>> getBusinessHours(String restaurantId) async {
    try {
      final response = await _dio.get(ApiConstants.restaurantBusinessHours(restaurantId));
      final data = unwrapData(response) as List<dynamic>;
      return data.map((e) => BusinessHoursEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<List<BusinessHoursEntry>> updateBusinessHours(String restaurantId, List<BusinessHoursEntry> entries) async {
    try {
      final response = await _dio.put(ApiConstants.restaurantBusinessHours(restaurantId), data: {
        'entries': entries.map((e) => e.toJson()).toList(),
      });
      final data = unwrapData(response) as List<dynamic>;
      return data.map((e) => BusinessHoursEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
