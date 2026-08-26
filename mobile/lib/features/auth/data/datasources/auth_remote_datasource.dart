import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/auth_result_model.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  /// Sends a login/registration OTP to [phoneNumber]. Returns whether this
  /// number has no name on file yet, so the caller knows to collect one
  /// before/while verifying.
  Future<bool> requestOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(ApiConstants.otpRequest, data: {'phone_number': phoneNumber});
      final data = unwrapData(response) as Map<String, dynamic>;
      return data['is_new_user'] as bool? ?? false;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AuthResultModel> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.otpVerify, data: {
        'phone_number': phoneNumber,
        'otp': otp,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      });
      return AuthResultModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post(ApiConstants.logout, data: {'refresh': refreshToken});
    } on DioException catch (e) {
      // Logging out should succeed locally even if the network call fails
      // (e.g. token already expired) — swallow anything but surface it for callers that care.
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.me);
      return UserModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<UserModel> updateProfile({required String fullName, required String phoneNumber}) async {
    try {
      final response = await _dio.patch(ApiConstants.me, data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
      });
      return UserModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
