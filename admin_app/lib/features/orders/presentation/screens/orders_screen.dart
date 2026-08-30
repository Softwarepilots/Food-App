import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/admin_order_model.dart';
import '../providers/admin_order_list_provider.dart';

/// Platform-wide order visibility for admins — read-only, no status
/// transitions (those belong to the restaurant-owner and delivery-partner
/// apps).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminOrderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminOrderListProvider.notifier).refresh(),
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
                DropdownButton<OrderStatus?>(
                  value: state.statusFilter,
                  items: [
                    for (final status in orderStatusFilters)
                      DropdownMenuItem(value: status, child: Text(orderStatusFilterLabel(status))),
                  ],
                  onChanged: (status) => ref.read(adminOrderListProvider.notifier).setStatusFilter(status),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AdminOrderListState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(adminOrderListProvider.notifier).refresh());
    }
    if (state.orders.isEmpty) {
      return const EmptyView(
        title: 'No orders',
        message: 'No orders match this filter.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(adminOrderListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Order #')),
            DataColumn(label: Text('Restaurant')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Placed')),
          ],
          rows: [
            for (final order in state.orders)
              DataRow(cells: [
                DataCell(Text(order.orderNumber)),
                DataCell(Text(order.restaurantName)),
                DataCell(Text(order.customerName)),
                DataCell(_StatusBadge(status: order.status)),
                DataCell(Text(Formatters.currency(order.totalAmount))),
                DataCell(Text(Formatters.dateTime(order.createdAt))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.outForDelivery:
      case OrderStatus.readyForPickup:
        return AppColors.secondaryDark;
      case OrderStatus.placed:
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w600)),
    );
  }
}
