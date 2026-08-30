import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/restaurant_admin_model.dart';
import '../providers/restaurant_admin_provider.dart';

class RestaurantsScreen extends ConsumerStatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  ConsumerState<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends ConsumerState<RestaurantsScreen> {
  String? _actingOnId;

  Future<void> _approve(RestaurantAdminModel restaurant) async {
    setState(() => _actingOnId = restaurant.id);
    try {
      await ref.read(restaurantAdminListProvider.notifier).approve(restaurant.id);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  Future<void> _reject(RestaurantAdminModel restaurant) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject restaurant'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'Why is this restaurant being rejected?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _actingOnId = restaurant.id);
    try {
      await ref.read(restaurantAdminListProvider.notifier).reject(restaurant.id, reason);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    final failure = Failure.fromException(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restaurantAdminListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(restaurantAdminListProvider.notifier).refresh(),
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
                Text('Status:', style: AppTextStyles.bodyMedium),
                const SizedBox(width: 12),
                DropdownButton<RestaurantApprovalFilter>(
                  value: state.filter,
                  items: [
                    for (final filter in RestaurantApprovalFilter.values)
                      DropdownMenuItem(value: filter, child: Text(filter.label)),
                  ],
                  onChanged: (filter) {
                    if (filter != null) ref.read(restaurantAdminListProvider.notifier).setFilter(filter);
                  },
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

  Widget _buildBody(RestaurantAdminListState state) {
    if (state.isLoading && state.restaurants.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.restaurants.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(restaurantAdminListProvider.notifier).refresh());
    }
    if (state.restaurants.isEmpty) {
      return const EmptyView(
        title: 'No restaurants',
        message: 'No restaurants match this filter.',
        icon: Icons.storefront_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(restaurantAdminListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Approval')),
            DataColumn(label: Text('Active')),
            DataColumn(label: Text('Accepting orders')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final restaurant in state.restaurants)
              DataRow(cells: [
                DataCell(Text(restaurant.name)),
                DataCell(Text(restaurant.city)),
                DataCell(_ApprovalBadge(status: restaurant.approvalStatus)),
                DataCell(Icon(
                  restaurant.isActive ? Icons.check_circle : Icons.cancel,
                  color: restaurant.isActive ? AppColors.success : AppColors.error,
                  size: 18,
                )),
                DataCell(Icon(
                  restaurant.isAcceptingOrders ? Icons.check_circle : Icons.cancel,
                  color: restaurant.isAcceptingOrders ? AppColors.success : AppColors.error,
                  size: 18,
                )),
                DataCell(
                  restaurant.isPending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _actingOnId == restaurant.id ? null : () => _approve(restaurant),
                              child: const Text('Approve'),
                            ),
                            TextButton(
                              onPressed: _actingOnId == restaurant.id ? null : () => _reject(restaurant),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Reject'),
                            ),
                          ],
                        )
                      : const Text('—'),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  final String status;

  const _ApprovalBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w600)),
    );
  }
}
