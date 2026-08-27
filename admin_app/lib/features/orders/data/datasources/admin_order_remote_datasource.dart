import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/admin_order_model.dart';

class AdminOrderRemoteDataSource {
  final Dio _dio;

  AdminOrderRemoteDataSource(this._dio);

  Future<PaginatedResult<AdminOrderModel>> getOrders({String? status}) async {
    try {
      final response = await _dio.get(ApiConstants.adminOrders, queryParameters: {
        'status': ?status,
      });
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => AdminOrderModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
