import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/partner_profile_model.dart';

class PartnerRemoteDataSource {
  final Dio _dio;

  PartnerRemoteDataSource(this._dio);

  /// Returns `null` (rather than throwing) when the partner hasn't created
  /// their profile yet — the backend responds 404 for that case since this
  /// is a single-object "me" endpoint, not a list.
  Future<PartnerProfileModel?> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.partnerProfile);
      return PartnerProfileModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<PartnerProfileModel> createProfile({
    required String vehicleType,
    required String vehicleNumber,
    required String licenseNumber,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.partnerProfile, data: {
        'vehicle_type': vehicleType,
        'vehicle_number': vehicleNumber,
        'license_number': licenseNumber,
      });
      return PartnerProfileModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<PartnerProfileModel> updateStatus(String status) async {
    try {
      final response = await _dio.patch(ApiConstants.partnerStatus, data: {'status': status});
      return PartnerProfileModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
