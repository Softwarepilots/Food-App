import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/delivery_partner_admin_model.dart';
import '../providers/delivery_partner_admin_provider.dart';

class DeliveryPartnersScreen extends ConsumerStatefulWidget {
  const DeliveryPartnersScreen({super.key});

  @override
  ConsumerState<DeliveryPartnersScreen> createState() => _DeliveryPartnersScreenState();
}

class _DeliveryPartnersScreenState extends ConsumerState<DeliveryPartnersScreen> {
  String? _actingOnId;

  Future<void> _toggleVerified(DeliveryPartnerAdminModel partner) async {
    setState(() => _actingOnId = partner.id);
    try {
      await ref.read(deliveryPartnerAdminListProvider.notifier).setVerified(partner.id, !partner.isVerified);
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryPartnerAdminListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Partners'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(deliveryPartnerAdminListProvider.notifier).refresh(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Verification:', style: AppTextStyles.bodyMedium),
                const SizedBox(width: 12),
                DropdownButton<DeliveryVerificationFilter>(
                  value: state.filter,
                  items: [
                    for (final filter in DeliveryVerificationFilter.values)
                      DropdownMenuItem(value: filter, child: Text(filter.label)),
                  ],
                  onChanged: (filter) {
                    if (filter != null) ref.read(deliveryPartnerAdminListProvider.notifier).setFilter(filter);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DeliveryPartnerAdminListState state) {
    if (state.isLoading && state.partners.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.partners.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(deliveryPartnerAdminListProvider.notifier).refresh());
    }
    if (state.partners.isEmpty) {
      return const EmptyView(
        title: 'No delivery partners',
        message: 'No delivery partners match this filter.',
        icon: Icons.two_wheeler_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(deliveryPartnerAdminListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Vehicle')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Verified')),
            DataColumn(label: Text('Deliveries')),
            DataColumn(label: Text('Rating')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final partner in state.partners)
              DataRow(cells: [
                DataCell(Text(partner.fullName.isEmpty ? '—' : partner.fullName)),
                DataCell(Text(partner.phoneNumber)),
                DataCell(Text('${partner.vehicleType} · ${partner.vehicleNumber}')),
                DataCell(_StatusBadge(status: partner.status)),
                DataCell(Icon(
                  partner.isVerified ? Icons.verified : Icons.pending_outlined,
                  color: partner.isVerified ? AppColors.success : AppColors.warning,
                  size: 18,
                )),
                DataCell(Text('${partner.totalDeliveries}')),
                DataCell(Text(partner.ratingAvg.toStringAsFixed(1))),
                DataCell(
                  TextButton(
                    onPressed: _actingOnId == partner.id ? null : () => _toggleVerified(partner),
                    style: TextButton.styleFrom(foregroundColor: partner.isVerified ? AppColors.error : AppColors.success),
                    child: Text(partner.isVerified ? 'Unverify' : 'Verify'),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'online':
        return AppColors.success;
      case 'on_delivery':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w600)),
    );
  }
}
