import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final Dio _dio;

  OrderRemoteDataSource(this._dio);

  Future<OrderModel> createOrder({
    required String restaurantId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.orders, data: {
        'restaurant_id': restaurantId,
        'delivery_address_id': addressId,
        'items': items,
        'payment_method': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<PaginatedResult<OrderModel>> getOrders({int page = 1}) async {
    try {
      final response = await _dio.get(ApiConstants.orders, queryParameters: {'page': page});
      return PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => OrderModel.fromJson(json),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<OrderModel> getOrderDetail(String id) async {
    try {
      final response = await _dio.get(ApiConstants.orderDetail(id));
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<OrderModel> cancelOrder(String id, {String? reason}) async {
    try {
      final response = await _dio.post(ApiConstants.orderCancel(id), data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      return OrderModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> submitReview(
    String orderId, {
    required int rating,
    String? comment,
    int? deliveryRating,
  }) async {
    try {
      await _dio.post(ApiConstants.orderReview(orderId), data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (deliveryRating != null) 'delivery_rating': deliveryRating,
      });
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
