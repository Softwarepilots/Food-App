import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/admin_user_model.dart';
import '../providers/admin_users_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));
  String? _actingOnId;

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(AdminUserModel user) async {
    setState(() => _actingOnId = user.id);
    try {
      await ref.read(adminUsersListProvider.notifier).setActive(user.id, !user.isActive);
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminUsersListProvider.notifier).refresh(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<String?>(
                  value: state.roleFilter,
                  items: [
                    for (final role in userRoleFilters) DropdownMenuItem(value: role, child: Text(roleFilterLabel(role))),
                  ],
                  onChanged: (role) => ref.read(adminUsersListProvider.notifier).setRoleFilter(role),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name, email, or phone',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (value) => _debouncer(() => ref.read(adminUsersListProvider.notifier).setSearch(value.trim())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AdminUsersListState state) {
    if (state.isLoading && state.users.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.users.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(adminUsersListProvider.notifier).refresh());
    }
    if (state.users.isEmpty) {
      return const EmptyView(title: 'No users', message: 'No users match this filter.', icon: Icons.people_outline);
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(adminUsersListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email / Phone')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Joined')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final user in state.users)
              DataRow(cells: [
                DataCell(Text(user.fullName.isEmpty ? '—' : user.fullName)),
                DataCell(Text([user.email, user.phoneNumber].where((s) => s != null && s.isNotEmpty).join(' · '))),
                DataCell(Text(roleFilterLabel(user.role))),
                DataCell(_StatusBadge(isActive: user.isActive)),
                DataCell(Text(Formatters.date(user.createdAt))),
                DataCell(
                  TextButton(
                    onPressed: _actingOnId == user.id ? null : () => _toggleActive(user),
                    style: TextButton.styleFrom(foregroundColor: user.isActive ? AppColors.error : AppColors.success),
                    child: Text(user.isActive ? 'Deactivate' : 'Activate'),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        isActive ? 'active' : 'inactive',
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
