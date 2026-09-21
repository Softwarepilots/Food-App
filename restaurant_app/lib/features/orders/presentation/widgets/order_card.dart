import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/order_model.dart';
import 'accept_countdown.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final void Function(OrderStatus) onAdvance;
  final VoidCallback onReject;
  final bool isUpdating;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAdvance,
    required this.onReject,
    this.isUpdating = false,
  });

  Color get _statusColor {
    if (order.status == OrderStatus.cancelled) return AppColors.error;
    if (order.status == OrderStatus.delivered) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final nextStep = order.status.nextStep;
    final canReject = order.status == OrderStatus.placed || order.status == OrderStatus.accepted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${order.orderNumber}', style: AppTextStyles.titleMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(order.status.label, style: AppTextStyles.caption.copyWith(color: _statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(Formatters.relative(order.createdAt), style: AppTextStyles.caption),
              if (order.status == OrderStatus.placed && order.acceptDeadline != null) ...[
                const Spacer(),
                AcceptCountdown(deadline: order.acceptDeadline!),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (order.customerName.isNotEmpty || order.customerPhone.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [order.customerName, order.customerPhone].where((s) => s.isNotEmpty).join(' · '),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (order.deliveryAddressText.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(order.deliveryAddressText, style: AppTextStyles.bodySmall)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.quantity}x ${item.foodName}${item.variantName != null ? " (${item.variantName})" : ""}',
                style: AppTextStyles.bodySmall,
              ),
            ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Note: ${order.notes}', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (order.estimatedPrepMinutes != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Preparation time: ${order.estimatedPrepMinutes} min', style: AppTextStyles.caption),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Formatters.currency(order.totalAmount), style: AppTextStyles.titleMedium),
              Text(order.paymentMethod == 'cod' ? 'Cash on delivery' : 'Paid online', style: AppTextStyles.caption),
            ],
          ),
          if (nextStep != null || canReject) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canReject)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isUpdating ? null : onReject,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                      child: const Text('Reject'),
                    ),
                  ),
                if (canReject && nextStep != null) const SizedBox(width: 10),
                if (nextStep != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isUpdating ? null : () => onAdvance(nextStep),
                      child: Text(_actionLabel(nextStep)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _actionLabel(OrderStatus next) {
    switch (next) {
      case OrderStatus.accepted:
        return 'Accept order';
      case OrderStatus.preparing:
        return 'Start preparing';
      case OrderStatus.readyForPickup:
        return 'Mark ready for pickup';
      case OrderStatus.placed:
      case OrderStatus.outForDelivery:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return next.label;
    }
  }
}
