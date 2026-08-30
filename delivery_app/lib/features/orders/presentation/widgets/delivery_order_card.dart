import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/order_model.dart';

Future<void> _callCustomer(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  await launchUrl(uri);
}

/// Renders one order's restaurant/customer/item summary, with an optional
/// trailing action button — "Accept" on the job board, "Mark delivered" on
/// an active delivery, or nothing at all for history/read-only rows.
class DeliveryOrderCard extends StatelessWidget {
  final OrderModel order;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isUpdating;
  final bool showCustomerInfo;

  const DeliveryOrderCard({
    super.key,
    required this.order,
    this.actionLabel,
    this.onAction,
    this.isUpdating = false,
    this.showCustomerInfo = false,
  });

  Color get _statusColor {
    if (order.status == OrderStatus.cancelled) return AppColors.error;
    if (order.status == OrderStatus.delivered) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text('#${order.orderNumber}', style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(order.status.label, style: AppTextStyles.caption.copyWith(color: _statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(Formatters.relative(order.createdAt), style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(order.restaurantName, style: AppTextStyles.bodySmall)),
            ],
          ),
          if (showCustomerInfo && (order.customerName.isNotEmpty || order.customerPhone.isNotEmpty)) ...[
            const SizedBox(height: 4),
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
                if (order.customerPhone.isNotEmpty)
                  IconButton(
                    onPressed: () => _callCustomer(order.customerPhone),
                    icon: const Icon(Icons.call, size: 18, color: AppColors.primary),
                    tooltip: 'Call customer',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (order.deliveryAddressText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(order.deliveryAddressText, style: AppTextStyles.bodySmall)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.quantity}x ${item.foodName}${item.variantName != null ? " (${item.variantName})" : ""}',
                style: AppTextStyles.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Formatters.currency(order.totalAmount), style: AppTextStyles.titleMedium),
              Text(order.paymentMethod == 'cod' ? 'Cash on delivery' : 'Paid online', style: AppTextStyles.caption),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating ? null : onAction,
                child: isUpdating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
