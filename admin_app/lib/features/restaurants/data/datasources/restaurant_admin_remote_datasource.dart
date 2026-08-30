import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/restaurant_admin_model.dart';

class RestaurantAdminRemoteDataSource {
  final Dio _dio;

  RestaurantAdminRemoteDataSource(this._dio);

  Future<PaginatedResult<RestaurantAdminModel>> getRestaurants({String? approvalStatus}) async {
    try {
      final response = await _dio.get(ApiConstants.adminRestaurants, queryParameters: {
        'approval_status': ?approvalStatus,
      });
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => RestaurantAdminModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RestaurantAdminModel> approve(String restaurantId) async {
    try {
      final response = await _dio.post(ApiConstants.approveRestaurant(restaurantId));
      return RestaurantAdminModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<RestaurantAdminModel> reject(String restaurantId, String reason) async {
    try {
      final response = await _dio.post(ApiConstants.rejectRestaurant(restaurantId), data: {'reason': reason});
      return RestaurantAdminModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
