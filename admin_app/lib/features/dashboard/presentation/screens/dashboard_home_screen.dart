import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/dashboard_provider.dart';

class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardStatsProvider.notifier).refresh(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.read(dashboardStatsProvider.notifier).refresh(),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardStatsProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Users'),
                  const SizedBox(height: 12),
                  _StatGrid(cards: [
                    _StatCardData('Total Users', '${stats.users.total}', Icons.people_outline, AppColors.primary),
                    _StatCardData('Customers', '${stats.users.customer}', Icons.person_outline, AppColors.secondary),
                    _StatCardData('Restaurant Owners', '${stats.users.restaurantOwner}', Icons.storefront_outlined, AppColors.secondary),
                    _StatCardData('Delivery Partners', '${stats.users.deliveryPartner}', Icons.two_wheeler_outlined, AppColors.secondary),
                    _StatCardData('Admins', '${stats.users.admin}', Icons.admin_panel_settings_outlined, AppColors.secondary),
                  ]),
                  const SizedBox(height: 32),
                  _SectionHeader('Restaurants'),
                  const SizedBox(height: 12),
                  _StatGrid(cards: [
                    _StatCardData('Total Restaurants', '${stats.restaurants.total}', Icons.storefront, AppColors.primary),
                    _StatCardData('Pending Approvals', '${stats.restaurants.pending}', Icons.hourglass_empty, AppColors.warning),
                    _StatCardData('Approved', '${stats.restaurants.approved}', Icons.check_circle_outline, AppColors.success),
                    _StatCardData('Rejected', '${stats.restaurants.rejected}', Icons.cancel_outlined, AppColors.error),
                  ]),
                  const SizedBox(height: 32),
                  _SectionHeader('Orders'),
                  const SizedBox(height: 12),
                  _StatGrid(cards: [
                    _StatCardData('Active Orders', '${stats.orders.active}', Icons.local_shipping_outlined, AppColors.primary),
                    _StatCardData("Today's Orders", '${stats.orders.todayCount}', Icons.today_outlined, AppColors.secondary),
                    _StatCardData("Today's Revenue", Formatters.currency(stats.orders.todayRevenue), Icons.payments_outlined, AppColors.success),
                    _StatCardData('Total Orders', '${stats.orders.total}', Icons.receipt_long_outlined, AppColors.secondary),
                  ]),
                  const SizedBox(height: 32),
                  _SectionHeader('Delivery'),
                  const SizedBox(height: 12),
                  _StatGrid(cards: [
                    _StatCardData('Online Riders', '${stats.delivery.online}', Icons.wifi_tethering, AppColors.success),
                    _StatCardData('Unverified Riders', '${stats.delivery.unverified}', Icons.pending_outlined, AppColors.warning),
                    _StatCardData('Total Riders', '${stats.delivery.total}', Icons.two_wheeler, AppColors.primary),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.headlineSmall);
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCardData(this.label, this.value, this.icon, this.color);
}

class _StatGrid extends StatelessWidget {
  final List<_StatCardData> cards;

  const _StatGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [for (final card in cards) _StatCard(data: card)],
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(data.value, style: AppTextStyles.headlineLarge),
          const SizedBox(height: 4),
          Text(data.label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
