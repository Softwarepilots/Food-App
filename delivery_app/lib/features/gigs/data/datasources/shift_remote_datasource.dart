import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/shift_model.dart';

class ShiftRemoteDataSource {
  final Dio _dio;

  ShiftRemoteDataSource(this._dio);

  Future<PaginatedResult<ShiftModel>> getUpcomingShifts() async {
    try {
      final response = await _dio.get(ApiConstants.shifts);
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => ShiftModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<PaginatedResult<ShiftModel>> getMyShifts() async {
    try {
      final response = await _dio.get(ApiConstants.myShifts);
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => ShiftModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<ShiftModel> bookShift(String shiftId) async {
    try {
      final response = await _dio.post(ApiConstants.bookShift(shiftId));
      return ShiftModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<ShiftModel> cancelShift(String shiftId) async {
    try {
      final response = await _dio.post(ApiConstants.cancelShift(shiftId));
      return ShiftModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
