import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../restaurant/data/models/restaurant_model.dart';
import '../../../restaurant/presentation/providers/restaurant_provider.dart';
import '../../data/models/dashboard_model.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final restaurant = ref.watch(myRestaurantProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: dashboardAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorView(
                  failure: Failure.fromException(error),
                  onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
                ),
              ),
            ],
          ),
          data: (dashboard) {
            if (dashboard == null || restaurant == null) {
              return const Center(child: Text('No restaurant yet.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(dashboard: dashboard, restaurant: restaurant),
                const SizedBox(height: 20),
                Text("Today's overview", style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _StatCard(
                      label: "Today's Orders",
                      value: '${dashboard.todayOrdersCount}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.primary,
                    ),
                    _StatCard(
                      label: "Today's Sales",
                      value: dashboard.todaySales != null ? Formatters.currency(dashboard.todaySales!) : '—',
                      icon: Icons.payments_outlined,
                      color: AppColors.secondaryDark,
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: '${dashboard.pendingOrdersCount}',
                      icon: Icons.hourglass_empty,
                      color: AppColors.warning,
                    ),
                    _StatCard(
                      label: 'Completed',
                      value: '${dashboard.completedOrdersCount}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text("Today's performance", style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _PerformanceRow(label: 'Orders', value: '${dashboard.todayOrdersCount}'),
                      const Divider(height: 20, color: AppColors.divider),
                      _PerformanceRow(
                        label: 'Average order value',
                        value: dashboard.averageOrderValue != null ? Formatters.currency(dashboard.averageOrderValue!) : '—',
                      ),
                      const Divider(height: 20, color: AppColors.divider),
                      _PerformanceRow(
                        label: 'Cancellation',
                        value: '${dashboard.cancellationRatePercent.toStringAsFixed(1)}%',
                      ),
                      const Divider(height: 20, color: AppColors.divider),
                      _PerformanceRow(label: 'Rating', value: '${dashboard.rating.toStringAsFixed(1)} ⭐'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  final DashboardModel dashboard;
  final RestaurantModel restaurant;

  const _StatusCard({required this.dashboard, required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepting = restaurant.isAcceptingOrders;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dashboard.restaurantName, style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accepting ? AppColors.success : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      accepting ? 'Accepting Orders' : 'Restaurant is currently offline',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: accepting,
            activeTrackColor: AppColors.success,
            onChanged: (value) => ref.read(myRestaurantProvider.notifier).setAcceptingOrders(value),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge),
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PerformanceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.titleMedium),
      ],
    );
  }
}
