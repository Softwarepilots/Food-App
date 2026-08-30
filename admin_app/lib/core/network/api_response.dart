import 'package:dio/dio.dart';
import '../error/app_exception.dart';

/// Pagination metadata returned alongside list endpoints, matching the
/// backend's `apps.common.pagination.paginated_response` envelope:
/// `{"success": true, "data": [...], "meta": {"count":, "next":, "previous":}}`.
class ApiMeta {
  final int count;
  final String? next;
  final String? previous;

  const ApiMeta({required this.count, this.next, this.previous});

  factory ApiMeta.fromJson(Map<String, dynamic> json) => ApiMeta(
        count: json['count'] as int? ?? 0,
        next: json['next'] as String?,
        previous: json['previous'] as String?,
      );

  bool get hasMore => next != null;
}

/// A parsed paginated list response: the page of items plus pagination info.
class PaginatedResult<T> {
  final List<T> items;
  final ApiMeta meta;

  const PaginatedResult({required this.items, required this.meta});

  factory PaginatedResult.fromJson(Map<String, dynamic> envelope, T Function(Map<String, dynamic>) fromJson) {
    final rawData = envelope['data'] as List<dynamic>? ?? [];
    return PaginatedResult(
      items: rawData.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      meta: ApiMeta.fromJson(envelope['meta'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// Unwraps the backend's standard success envelope (`{"success": true, "data": ...}`)
/// and hands the caller just the `data` payload.
dynamic unwrapData(Response response) {
  final body = response.data;
  if (body is Map<String, dynamic> && body.containsKey('data')) {
    return body['data'];
  }
  return body;
}

/// Converts a [DioException] into a typed [AppException] the rest of the app
/// can handle uniformly, extracting the backend's
/// `{"error": {"code":, "message":, "details":}}` envelope when present.
AppException mapDioExceptionToAppException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutAppException();
    case DioExceptionType.connectionError:
      return const NetworkException();
    case DioExceptionType.cancel:
      return const UnknownException('Request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkException('A secure connection could not be established.');
    case DioExceptionType.badResponse:
      return _mapBadResponse(error);
    case DioExceptionType.unknown:
    default:
      return const NetworkException();
  }
}

AppException _mapBadResponse(DioException error) {
  final statusCode = error.response?.statusCode;
  final body = error.response?.data;

  String message = 'Something went wrong. Please try again.';
  String code = 'server_error';
  Map<String, dynamic> details = const {};

  if (body is Map<String, dynamic>) {
    final errorObj = body['error'];
    if (errorObj is Map<String, dynamic>) {
      message = errorObj['message'] as String? ?? message;
      code = errorObj['code'] as String? ?? code;
      final rawDetails = errorObj['details'];
      if (rawDetails is Map<String, dynamic>) {
        details = rawDetails;
      }
    }
  }

  if (statusCode == 401) {
    return UnauthorizedException(message);
  }
  if (statusCode == 400 || statusCode == 422) {
    return ValidationException(message, fieldErrors: details);
  }
  if (statusCode == 429) {
    return ServerException(message.isEmpty ? 'Too many requests. Please slow down.' : message, statusCode: statusCode, code: 'rate_limited');
  }
  return ServerException(message, statusCode: statusCode, code: code);
}
