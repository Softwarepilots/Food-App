import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/order_model.dart';
import '../providers/order_list_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/prep_time_picker.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String? _updatingOrderId;

  Future<void> _advance(String orderId, OrderStatus status) async {
    int? prepTimeMinutes;
    if (status == OrderStatus.accepted) {
      prepTimeMinutes = await showPrepTimePicker(context);
      if (prepTimeMinutes == null) return; // owner backed out of the picker
    }
    if (!mounted) return;
    setState(() => _updatingOrderId = orderId);
    try {
      await ref.read(orderListProvider.notifier).advanceStatus(orderId, status, prepTimeMinutes: prepTimeMinutes);
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderListProvider);

    final active = state.orders.where((o) => o.status.isActive).toList();
    final history = state.orders.where((o) => !o.status.isActive).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'History')]),
        ),
        body: TabBarView(
          children: [
            _buildList(state, active, emptyMessage: 'No active orders right now.'),
            _buildList(state, history, emptyMessage: 'No past orders yet.'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(OrderListState state, List<OrderModel> orders, {required String emptyMessage}) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(orderListProvider.notifier).refresh());
    }
    if (orders.isEmpty) {
      return EmptyView(title: 'Nothing here', message: emptyMessage, icon: Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(orderListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCard(
            order: order,
            isUpdating: _updatingOrderId == order.id,
            onAdvance: (status) => _advance(order.id, status),
            onReject: () => _advance(order.id, OrderStatus.cancelled),
          );
        },
      ),
    );
  }
}
