import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

/// Thin wrapper over [FlutterSecureStorage] so the rest of the app never
/// touches the storage package directly — makes it trivial to swap or mock.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: StorageKeys.accessToken);

  Future<String?> get refreshToken => _storage.read(key: StorageKeys.refreshToken);

  Future<void> saveCachedUser(String userJson) => _storage.write(key: StorageKeys.cachedUser, value: userJson);

  Future<String?> get cachedUser => _storage.read(key: StorageKeys.cachedUser);

  Future<void> clear() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.cachedUser);
  }
}
