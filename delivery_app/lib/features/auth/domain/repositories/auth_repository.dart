import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<AuthResultModel> login({required String email, required String password});

  Future<AuthResultModel> register({
    required String email,
    required String phoneNumber,
    required String fullName,
    required String password,
  });

  Future<void> logout();

  Future<UserModel> getCurrentUser();
}
