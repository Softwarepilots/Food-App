import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/order_model.dart';
import '../providers/order_detail_provider.dart';
import '../widgets/delivery_partner_card.dart';
import '../widgets/delivery_route_preview.dart';
import '../widgets/order_review_card.dart';
import '../widgets/order_status_timeline.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.read(orderDetailProvider(orderId).notifier).refresh(),
        ),
        data: (order) => _OrderDetailBody(orderId: orderId, order: order),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  final String orderId;
  final OrderModel order;

  const _OrderDetailBody({required this.orderId, required this.order});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(orderDetailProvider(orderId).notifier).cancelOrder();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled')));
      }
    } catch (e) {
      if (!context.mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(order.restaurantName, style: AppTextStyles.headlineSmall)),
            Text('#${order.orderNumber}', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(Formatters.dateTime(order.createdAt), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        if (order.status.isActive && order.status == OrderStatus.outForDelivery) ...[
          const DeliveryRoutePreview(),
          const SizedBox(height: 16),
        ],
        Text('Status', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        OrderStatusTimeline(order: order),
        if (order.deliveryPartnerName != null) ...[
          const SizedBox(height: 16),
          DeliveryPartnerCard(name: order.deliveryPartnerName!, phone: order.deliveryPartnerPhone),
        ],
        const SizedBox(height: 20),
        Text('Delivery address', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Text(order.deliveryAddressText, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Text('Items', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final item in order.items) _OrderItemRow(item: item),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Bill details', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _BillRow(label: 'Item total', value: order.subtotal),
              _BillRow(label: 'Delivery fee', value: order.deliveryFee),
              _BillRow(label: 'Taxes', value: order.taxAmount),
              if (order.discountAmount > 0) _BillRow(label: 'Discount', value: -order.discountAmount),
              const Divider(color: AppColors.divider),
              _BillRow(label: 'Total paid', value: order.totalAmount, isTotal: true),
            ],
          ),
        ),
        if (order.canCancel) ...[
          const SizedBox(height: 24),
          AppButton(label: 'Cancel order', variant: AppButtonVariant.outlined, onPressed: () => _cancel(context, ref)),
        ],
        if (order.status == OrderStatus.delivered) ...[
          const SizedBox(height: 24),
          OrderReviewCard(orderId: orderId, deliveryPartnerName: order.deliveryPartnerName),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItemModel item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.quantity}x', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName, style: AppTextStyles.bodyMedium),
                if (item.variantName != null) Text(item.variantName!, style: AppTextStyles.caption),
                if (item.addonNames.isNotEmpty) Text(item.addonNames.join(', '), style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(Formatters.currency(item.lineTotal), style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;

  const _BillRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    final style = isTotal ? AppTextStyles.titleMedium : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Formatters.currency(value), style: style),
        ],
      ),
    );
  }
}
