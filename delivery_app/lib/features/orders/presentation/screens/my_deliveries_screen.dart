import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/order_model.dart';
import '../providers/my_deliveries_provider.dart';
import '../widgets/delivery_order_card.dart';

class MyDeliveriesScreen extends ConsumerStatefulWidget {
  const MyDeliveriesScreen({super.key});

  @override
  ConsumerState<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends ConsumerState<MyDeliveriesScreen> {
  String? _deliveringOrderId;

  Future<void> _markDelivered(String orderId) async {
    setState(() => _deliveringOrderId = orderId);
    try {
      await ref.read(myDeliveriesProvider.notifier).markDelivered(orderId);
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _deliveringOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myDeliveriesProvider);

    final active = state.orders.where((o) => o.status.isActive).toList();
    final history = state.orders.where((o) => !o.status.isActive).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My deliveries'),
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'History')]),
        ),
        body: TabBarView(
          children: [
            _buildList(state, active, emptyMessage: 'No active deliveries right now.', showAction: true),
            _buildList(state, history, emptyMessage: 'No completed deliveries yet.', showAction: false),
          ],
        ),
      ),
    );
  }

  Widget _buildList(MyDeliveriesState state, List<OrderModel> orders, {required String emptyMessage, required bool showAction}) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(myDeliveriesProvider.notifier).refresh());
    }
    if (orders.isEmpty) {
      return EmptyView(title: 'Nothing here', message: emptyMessage, icon: Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(myDeliveriesProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return DeliveryOrderCard(
            order: order,
            showCustomerInfo: true,
            actionLabel: showAction ? 'Mark delivered' : null,
            onAction: showAction ? () => _markDelivered(order.id) : null,
            isUpdating: _deliveringOrderId == order.id,
          );
        },
      ),
    );
  }
}
