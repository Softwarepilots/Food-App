import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';

class RestaurantSettingsScreen extends ConsumerWidget {
  const RestaurantSettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(myRestaurantProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(user?.fullName ?? '', style: AppTextStyles.titleLarge),
          Text(user?.email ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          restaurantAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LoadingIndicator()),
            error: (error, _) => ErrorView(
              failure: Failure.fromException(error),
              onRetry: () => ref.read(myRestaurantProvider.notifier).refresh(),
            ),
            data: (restaurant) {
              if (restaurant == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 4),
                    Text('${restaurant.addressLine}, ${restaurant.city}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: restaurant.isApproved ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        restaurant.isApproved ? 'Approved' : 'Pending admin approval',
                        style: AppTextStyles.caption.copyWith(
                          color: restaurant.isApproved ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 24, color: AppColors.divider),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Accepting orders'),
                      subtitle: const Text('Turn off to pause new incoming orders temporarily.'),
                      value: restaurant.isAcceptingOrders,
                      onChanged: (value) => ref.read(myRestaurantProvider.notifier).setAcceptingOrders(value),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Log out', style: TextStyle(color: AppColors.error)),
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}
