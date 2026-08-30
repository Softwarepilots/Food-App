import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../profile/presentation/providers/partner_provider.dart';
import '../providers/available_orders_provider.dart';
import '../widgets/delivery_order_card.dart';

class AvailableOrdersScreen extends ConsumerStatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  ConsumerState<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends ConsumerState<AvailableOrdersScreen> {
  String? _acceptingOrderId;
  bool _isGoingOnline = false;

  Future<void> _goOnline() async {
    setState(() => _isGoingOnline = true);
    try {
      await ref.read(myPartnerProfileProvider.notifier).goOnline();
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isGoingOnline = false);
    }
  }

  Future<void> _accept(String orderId) async {
    setState(() => _acceptingOrderId = orderId);
    try {
      await ref.read(availableOrdersProvider.notifier).accept(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted.')));
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _acceptingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availableOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Available orders')),
      body: !state.isOnline ? _buildOfflineState() : _buildOrdersList(state),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_tethering_off_rounded, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text("You're offline", style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Go online to see available orders near you.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: AppButton(label: 'Go online', onPressed: _goOnline, isLoading: _isGoingOnline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(AvailableOrdersState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(availableOrdersProvider.notifier).refresh());
    }
    if (state.orders.isEmpty) {
      return const EmptyView(
        title: 'No orders available right now',
        message: "We'll show new orders here as soon as they're ready for pickup.",
        icon: Icons.two_wheeler_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(availableOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = state.orders[index];
          return DeliveryOrderCard(
            order: order,
            actionLabel: 'Accept',
            onAction: () => _accept(order.id),
            isUpdating: _acceptingOrderId == order.id,
          );
        },
      ),
    );
  }
}
