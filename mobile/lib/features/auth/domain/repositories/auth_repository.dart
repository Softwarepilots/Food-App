import '../../data/models/auth_result_model.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  /// Returns true if [phoneNumber] has no name on file yet (new account).
  Future<bool> requestOtp(String phoneNumber);

  Future<AuthResultModel> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? fullName,
  });

  Future<void> logout();

  Future<UserModel> getCurrentUser();

  Future<UserModel> updateProfile({required String fullName, required String phoneNumber});
}
