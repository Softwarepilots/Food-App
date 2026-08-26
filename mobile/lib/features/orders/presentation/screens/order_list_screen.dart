import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/order_list_provider.dart';
import '../widgets/order_card.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(orderListProvider.notifier).loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(OrderListState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(orderListProvider.notifier).refresh());
    }
    if (state.orders.isEmpty) {
      return const EmptyView(
        title: 'No orders yet',
        message: 'Your order history will show up here once you place your first order.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(orderListProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.orders.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= state.orders.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingIndicator(size: 20));
          }
          final order = state.orders[index];
          return OrderCard(order: order, onTap: () => context.push('/orders/${order.id}'));
        },
      ),
    );
  }
}
