import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../checkout/presentation/providers/address_provider.dart';
import '../../../checkout/presentation/widgets/address_tile.dart';

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This address will be removed from your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressListProvider.notifier).deleteAddress(id);
    } catch (e) {
      if (!context.mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/checkout/add-address'),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/checkout/add-address'),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AddressListState state) {
    if (state.isLoading && state.addresses.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.addresses.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(addressListProvider.notifier).loadAddresses());
    }
    if (state.addresses.isEmpty) {
      return const EmptyView(
        title: 'No saved addresses',
        message: 'Add a delivery address to speed up your checkout.',
        icon: Icons.location_off_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(addressListProvider.notifier).loadAddresses(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: state.addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final address = state.addresses[index];
          return AddressTile(
            address: address,
            isSelected: address.isDefault,
            onTap: () => ref.read(addressListProvider.notifier).setDefault(address.id),
            onDelete: () => _delete(context, ref, address.id),
          );
        },
      ),
    );
  }
}
