import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.authenticated(UserModel user) : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [status, user];
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Core's network layer signals here (via a decoupled provider) when a
    // token refresh fails — react by dropping back to unauthenticated.
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (previous != null && next != previous) {
        state = const AuthState.unauthenticated();
      }
    });
    _restoreSession();
    return const AuthState.unknown();
  }

  Future<void> _restoreSession() async {
    final storage = ref.read(secureStorageServiceProvider);
    final token = await storage.accessToken;
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      state = AuthState.authenticated(user);
    } catch (_) {
      await storage.clear();
      state = const AuthState.unauthenticated();
    }
  }

  /// Sends a login/registration OTP to [phoneNumber]. Returns whether this
  /// number has no name on file yet.
  Future<bool> requestOtp(String phoneNumber) => ref.read(authRepositoryProvider).requestOtp(phoneNumber);

  Future<void> verifyOtp({required String phoneNumber, required String otp, String? fullName}) async {
    final result = await ref.read(authRepositoryProvider).verifyOtp(
          phoneNumber: phoneNumber,
          otp: otp,
          fullName: fullName,
        );
    state = AuthState.authenticated(result.user);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState.unauthenticated();
  }

  Future<void> refreshCurrentUser() async {
    if (!state.isAuthenticated) return;
    final user = await ref.read(authRepositoryProvider).getCurrentUser();
    state = AuthState.authenticated(user);
  }

  Future<void> updateProfile({required String fullName, required String phoneNumber}) async {
    final user = await ref.read(authRepositoryProvider).updateProfile(fullName: fullName, phoneNumber: phoneNumber);
    state = AuthState.authenticated(user);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
