import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/widgets/cart_summary.dart';
import '../providers/address_provider.dart';
import '../providers/checkout_provider.dart';
import '../widgets/address_tile.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  Future<void> _placeOrder(BuildContext context, WidgetRef ref, String addressId) async {
    try {
      final order = await ref.read(checkoutProvider.notifier).placeOrder(addressId: addressId);
      if (context.mounted) {
        context.pushReplacement('/orders/${order.id}');
      }
    } catch (e) {
      if (!context.mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final addressState = ref.watch(addressListProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final selectedAddress = addressState.selectedAddress;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery address', style: AppTextStyles.titleMedium),
              TextButton(
                onPressed: () => context.push('/checkout/add-address'),
                child: const Text('+ Add new'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (addressState.isLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingIndicator(size: 24))
          else if (addressState.addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  const Text('You have no saved addresses yet.'),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Add delivery address',
                    onPressed: () => context.push('/checkout/add-address'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final address in addressState.addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AddressTile(
                      address: address,
                      isSelected: selectedAddress?.id == address.id,
                      onTap: () => ref.read(addressListProvider.notifier).selectAddress(address.id),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text('Payment method', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Column(
            children: [
              for (final method in PaymentMethod.values)
                RadioListTile<PaymentMethod>(
                  contentPadding: EdgeInsets.zero,
                  value: method,
                  groupValue: checkoutState.paymentMethod,
                  activeColor: AppColors.primary,
                  title: Text(method.label),
                  onChanged: (value) {
                    if (value != null) ref.read(checkoutProvider.notifier).setPaymentMethod(value);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Add a note for the restaurant (optional)'),
            maxLines: 2,
            onChanged: (value) => ref.read(checkoutProvider.notifier).setNotes(value),
          ),
          const SizedBox(height: 20),
          CartSummary(subtotal: cart.subtotal, itemCount: cart.itemCount),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AppButton(
            label: 'Place order',
            isLoading: checkoutState.isPlacingOrder,
            onPressed: (selectedAddress == null || cart.isEmpty)
                ? null
                : () => _placeOrder(context, ref, selectedAddress.id),
          ),
        ),
      ),
    );
  }
}
