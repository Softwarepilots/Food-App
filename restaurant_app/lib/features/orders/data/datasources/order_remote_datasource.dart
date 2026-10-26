import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final Dio _dio;

  OrderRemoteDataSource(this._dio);

  Future<PaginatedResult<OrderModel>> getRestaurantOrders({int page = 1, String? status}) async {
    try {
      final response = await _dio.get(ApiConstants.restaurantOrders, queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      });
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => OrderModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<OrderModel> updateStatus(String orderId, OrderStatus status, {int? prepTimeMinutes}) async {
    try {
      final response = await _dio.patch(ApiConstants.orderStatus(orderId), data: {
        'status': status.apiValue,
        if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
      });
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
