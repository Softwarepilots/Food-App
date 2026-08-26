import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_response.dart';
import '../models/address_model.dart';

class AddressRemoteDataSource {
  final Dio _dio;

  AddressRemoteDataSource(this._dio);

  Future<List<AddressModel>> getAddresses() async {
    try {
      final response = await _dio.get(ApiConstants.addresses, queryParameters: {'page_size': 50});
      final result = PaginatedResult.fromJson(
        response.data as Map<String, dynamic>,
        (json) => AddressModel.fromJson(json),
      );
      return result.items;
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AddressModel> createAddress(AddressModel address) async {
    try {
      final response = await _dio.post(ApiConstants.addresses, data: address.toJson());
      return AddressModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AddressModel> updateAddress(String id, AddressModel address) async {
    try {
      final response = await _dio.patch(ApiConstants.addressDetail(id), data: address.toJson());
      return AddressModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _dio.delete(ApiConstants.addressDetail(id));
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }

  Future<AddressModel> setDefault(String id) async {
    try {
      final response = await _dio.patch(ApiConstants.addressDetail(id), data: {'is_default': true});
      return AddressModel.fromJson(unwrapData(response) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioExceptionToAppException(e);
    }
  }
}
