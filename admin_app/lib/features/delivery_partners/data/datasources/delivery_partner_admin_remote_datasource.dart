import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/delivery_partner_admin_model.dart';

class DeliveryPartnerAdminRemoteDataSource {
  final Dio _dio;

  DeliveryPartnerAdminRemoteDataSource(this._dio);

  Future<PaginatedResult<DeliveryPartnerAdminModel>> getPartners({bool? isVerified}) async {
    try {
      final response = await _dio.get(ApiConstants.adminDeliveryPartners, queryParameters: {
        'is_verified': ?isVerified,
      });
      return PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => DeliveryPartnerAdminModel.fromJson(json),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<DeliveryPartnerAdminModel> setVerified(String partnerId, bool isVerified) async {
    try {
      final response = await _dio.post(ApiConstants.verifyDeliveryPartner(partnerId), data: {'is_verified': isVerified});
      return DeliveryPartnerAdminModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
