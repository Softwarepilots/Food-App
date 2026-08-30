import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Attaches the bearer access token to every outgoing request and, on a 401,
/// transparently refreshes the token and retries the original request once.
/// Concurrent 401s share a single in-flight refresh call rather than each
/// firing their own.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;
  final Dio _refreshDio;
  final Future<void> Function() onSessionExpired;

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storageService,
    required Dio refreshDio,
    required this.onSessionExpired,
  })  : _storageService = storageService,
        _refreshDio = refreshDio;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storageService.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    final isRefreshCall = err.requestOptions.path.contains(ApiConstants.tokenRefresh);

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    final newAccessToken = await _refreshTokenSharing();
    if (newAccessToken == null) {
      await _storageService.clear();
      await onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      retryOptions.extra['retried'] = true;
      final response = await _refreshDio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Ensures only one refresh network call happens even if several requests
  /// 401 at the same moment — the rest await the same in-flight refresh.
  Future<String?> _refreshTokenSharing() async {
    if (_isRefreshing) {
      await _refreshCompleter?.future;
      return _storageService.accessToken;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();
    try {
      final refreshToken = await _storageService.refreshToken;
      if (refreshToken == null) return null;

      final response = await _refreshDio.post(
        ApiConstants.tokenRefresh,
        data: {'refresh': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final newAccess = data['access'] as String;
      final newRefresh = data['refresh'] as String? ?? refreshToken;
      await _storageService.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      return newAccess;
    } catch (_) {
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter?.complete();
      _refreshCompleter = null;
    }
  }
}
