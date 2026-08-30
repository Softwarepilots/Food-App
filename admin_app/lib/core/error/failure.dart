import 'package:equatable/equatable.dart';
import 'app_exception.dart';

/// UI-facing representation of an error. Screens/widgets should render
/// [message] (and optionally inspect [fieldErrors]) rather than working with
/// [AppException] subtypes directly.
class Failure extends Equatable {
  final String message;
  final String code;
  final Map<String, dynamic> fieldErrors;

  const Failure(this.message, {this.code = 'error', this.fieldErrors = const {}});

  factory Failure.fromException(Object error) {
    if (error is ValidationException) {
      return Failure(error.message, code: error.code, fieldErrors: error.fieldErrors);
    }
    if (error is AppException) {
      return Failure(error.message, code: error.code);
    }
    return const Failure('Something went wrong. Please try again.', code: 'unknown_error');
  }

  bool get isUnauthorized => code == 'unauthorized';
  bool get isNetworkError => code == 'network_error' || code == 'timeout';

  @override
  List<Object?> get props => [message, code, fieldErrors];
}
