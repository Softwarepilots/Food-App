import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/admin_user_model.dart';

class AdminUsersRemoteDataSource {
  final Dio _dio;

  AdminUsersRemoteDataSource(this._dio);

  Future<PaginatedResult<AdminUserModel>> getUsers({String? role, String? search}) async {
    try {
      final response = await _dio.get(ApiConstants.adminUsers, queryParameters: {
        'role': ?role,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return PaginatedResult.fromJson(response.data as Map<String, dynamic>, (json) => AdminUserModel.fromJson(json));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AdminUserModel> setActive(String userId, bool isActive) async {
    try {
      final response = await _dio.patch(ApiConstants.adminUserStatus(userId), data: {'is_active': isActive});
      return AdminUserModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
