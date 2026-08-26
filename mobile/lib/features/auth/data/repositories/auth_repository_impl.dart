import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_result_model.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService storageService,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService;

  @override
  Future<bool> requestOtp(String phoneNumber) => _remoteDataSource.requestOtp(phoneNumber);

  @override
  Future<AuthResultModel> verifyOtp({required String phoneNumber, required String otp, String? fullName}) async {
    final result = await _remoteDataSource.verifyOtp(phoneNumber: phoneNumber, otp: otp, fullName: fullName);
    await _storageService.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _storageService.refreshToken;
    try {
      if (refreshToken != null) {
        await _remoteDataSource.logout(refreshToken);
      }
    } finally {
      await _storageService.clear();
    }
  }

  @override
  Future<UserModel> getCurrentUser() => _remoteDataSource.getCurrentUser();

  @override
  Future<UserModel> updateProfile({required String fullName, required String phoneNumber}) {
    return _remoteDataSource.updateProfile(fullName: fullName, phoneNumber: phoneNumber);
  }
}
