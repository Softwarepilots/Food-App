import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/notifications/push_notification_provider.dart';
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
      if (!user.isAdmin) {
        await ref.read(authRepositoryProvider).logout();
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(user);
      unawaited(ref.read(pushNotificationServiceProvider).registerDevice());
    } catch (_) {
      await storage.clear();
      state = const AuthState.unauthenticated();
    }
  }

  /// Logs in, then enforces that only admin accounts may enter the shell —
  /// admin accounts are provisioned directly in the database (there's no
  /// self-registration), so any non-admin role reaching this point means the
  /// wrong account was used. Tokens are cleared and the caller sees a
  /// friendly [UnauthorizedException] rather than being routed past login.
  Future<void> login({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).login(email: email, password: password);
    if (!result.user.isAdmin) {
      await ref.read(authRepositoryProvider).logout();
      state = const AuthState.unauthenticated();
      throw const UnauthorizedException('This account does not have admin access.');
    }
    state = AuthState.authenticated(result.user);
    unawaited(ref.read(pushNotificationServiceProvider).registerDevice());
  }

  Future<void> logout() async {
    await ref.read(pushNotificationServiceProvider).unregisterDevice();
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState.unauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
