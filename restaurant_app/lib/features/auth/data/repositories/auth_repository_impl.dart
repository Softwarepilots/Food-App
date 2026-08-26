import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepositoryImpl({required AuthRemoteDataSource remoteDataSource, required SecureStorageService storageService})
      : _remoteDataSource = remoteDataSource,
        _storageService = storageService;

  Future<AuthResultModel> _persistAndReturn(AuthResultModel result) async {
    await _storageService.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result;
  }

  @override
  Future<AuthResultModel> login({required String email, required String password}) async {
    final result = await _remoteDataSource.login(email: email, password: password);
    return _persistAndReturn(result);
  }

  @override
  Future<AuthResultModel> register({
    required String email,
    required String phoneNumber,
    required String fullName,
    required String password,
  }) async {
    final result = await _remoteDataSource.register(
      email: email,
      phoneNumber: phoneNumber,
      fullName: fullName,
      password: password,
    );
    return _persistAndReturn(result);
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
}
