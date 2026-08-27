/// Exceptions thrown by the data layer (datasources) when a network call
/// fails. Repositories catch these and convert them into [Failure]s for the
/// presentation layer — see `failure.dart`.
sealed class AppException implements Exception {
  final String message;
  final String code;

  const AppException(this.message, {this.code = 'error'});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection. Please check your network.'])
      : super(code: 'network_error');
}

class TimeoutAppException extends AppException {
  const TimeoutAppException([super.message = 'The request timed out. Please try again.'])
      : super(code: 'timeout');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Your session has expired. Please log in again.'])
      : super(code: 'unauthorized');
}

class ValidationException extends AppException {
  final Map<String, dynamic> fieldErrors;

  const ValidationException(super.message, {this.fieldErrors = const {}}) : super(code: 'validation_error');
}

class ServerException extends AppException {
  final int? statusCode;

  const ServerException(super.message, {this.statusCode, super.code = 'server_error'});
}

class UnknownException extends AppException {
  const UnknownException([super.message = 'Something went wrong. Please try again.'])
      : super(code: 'unknown_error');
}
