import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/admin_users_remote_datasource.dart';
import '../../data/models/admin_user_model.dart';

final adminUsersRemoteDataSourceProvider = Provider<AdminUsersRemoteDataSource>((ref) {
  return AdminUsersRemoteDataSource(ref.watch(dioProvider));
});

/// `null` means "All roles".
const List<String?> userRoleFilters = [null, 'customer', 'restaurant_owner', 'delivery_partner', 'admin'];

String roleFilterLabel(String? role) {
  switch (role) {
    case 'customer':
      return 'Customer';
    case 'restaurant_owner':
      return 'Restaurant Owner';
    case 'delivery_partner':
      return 'Delivery Partner';
    case 'admin':
      return 'Admin';
    default:
      return 'All roles';
  }
}

class AdminUsersListState extends Equatable {
  final List<AdminUserModel> users;
  final String? roleFilter;
  final String search;
  final bool isLoading;
  final Failure? failure;

  const AdminUsersListState({
    this.users = const [],
    this.roleFilter,
    this.search = '',
    this.isLoading = false,
    this.failure,
  });

  AdminUsersListState copyWith({
    List<AdminUserModel>? users,
    String? roleFilter,
    bool clearRoleFilter = false,
    String? search,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AdminUsersListState(
      users: users ?? this.users,
      roleFilter: clearRoleFilter ? null : (roleFilter ?? this.roleFilter),
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [users, roleFilter, search, isLoading, failure];
}

class AdminUsersListNotifier extends Notifier<AdminUsersListState> {
  @override
  AdminUsersListState build() {
    Future.microtask(refresh);
    return const AdminUsersListState(isLoading: true);
  }

  Future<void> setRoleFilter(String? role) async {
    state = state.copyWith(roleFilter: role, clearRoleFilter: role == null);
    await refresh();
  }

  Future<void> setSearch(String search) async {
    state = state.copyWith(search: search);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref
          .read(adminUsersRemoteDataSourceProvider)
          .getUsers(role: state.roleFilter, search: state.search);
      state = state.copyWith(users: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> setActive(String userId, bool isActive) async {
    final updated = await ref.read(adminUsersRemoteDataSourceProvider).setActive(userId, isActive);
    state = state.copyWith(
      users: [for (final u in state.users) if (u.id == userId) updated else u],
    );
  }
}

final adminUsersListProvider = NotifierProvider<AdminUsersListNotifier, AdminUsersListState>(
  AdminUsersListNotifier.new,
);
