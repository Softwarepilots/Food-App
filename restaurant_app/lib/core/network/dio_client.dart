import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      contentType: 'application/json',
      headers: const {'Accept': 'application/json'},
    );

/// Builds the app's primary [Dio] client: base options + auth interceptor
/// (token attach/refresh) + request logging in debug builds.
///
/// [onSessionExpired] is invoked when a token refresh fails (refresh token
/// missing/expired) — wire this to clear auth state and route to login.
Dio createDioClient({
  required SecureStorageService storageService,
  required Future<void> Function() onSessionExpired,
}) {
  // Separate, interceptor-free client used only for the refresh call and for
  // retrying a failed request — prevents recursive 401 handling.
  final refreshDio = Dio(_baseOptions());

  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      storageService: storageService,
      refreshDio: refreshDio,
      onSessionExpired: onSessionExpired,
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true, logPrint: (obj) => debugPrint(obj.toString())),
    );
  }

  return dio;
}
