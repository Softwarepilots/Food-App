import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/order_model.dart';

class DeliveryOrderRemoteDataSource {
  final Dio _dio;

  DeliveryOrderRemoteDataSource(this._dio);

  /// Platform-wide list of `ready_for_pickup` orders not yet claimed by any
  /// delivery partner. Not filtered by proximity — no live location yet.
  Future<PaginatedResult<OrderModel>> getAvailableOrders() async {
    try {
      final response = await _dio.get(ApiConstants.availableOrders);
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => OrderModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  /// The current partner's own assigned orders, optionally filtered by
  /// status (e.g. `out_for_delivery` or `delivered`).
  Future<PaginatedResult<OrderModel>> getMyDeliveries({String? status}) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (status != null) queryParameters['status'] = status;
      final response = await _dio.get(ApiConstants.myDeliveries, queryParameters: queryParameters);
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => OrderModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<OrderModel> acceptOrder(String orderId) async {
    try {
      final response = await _dio.post(ApiConstants.acceptOrder(orderId));
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<OrderModel> markDelivered(String orderId) async {
    try {
      final response = await _dio.post(ApiConstants.deliverOrder(orderId));
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
