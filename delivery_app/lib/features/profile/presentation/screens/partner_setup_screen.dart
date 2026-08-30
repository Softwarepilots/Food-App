import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/partner_profile_model.dart';
import '../providers/partner_provider.dart';

/// Shown when the logged-in delivery partner has no profile yet — collects
/// vehicle + license details before they can go online and see jobs.
class PartnerSetupScreen extends ConsumerStatefulWidget {
  const PartnerSetupScreen({super.key});

  @override
  ConsumerState<PartnerSetupScreen> createState() => _PartnerSetupScreenState();
}

class _PartnerSetupScreenState extends ConsumerState<PartnerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.motorcycle;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(myPartnerProfileProvider.notifier).createProfile(
            vehicleType: _selectedVehicleType.apiValue,
            vehicleNumber: _vehicleNumberController.text.trim(),
            licenseNumber: _licenseNumberController.text.trim(),
          );
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      setState(() => _isSubmitting = false);
      return;
    }
    // On success, deliberately leave the button disabled/loading rather than
    // resetting _isSubmitting: the router redirects away from this screen
    // once myPartnerProfileProvider updates, but that redirect isn't
    // synchronous with this callback returning — re-enabling the button in
    // that gap let an impatient second tap fire a duplicate create request.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your rider profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us about your vehicle. An admin will verify your details before you can start accepting deliveries.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Text('Vehicle type', style: AppTextStyles.labelLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final type in VehicleType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: _selectedVehicleType == type,
                        onSelected: (_) => setState(() => _selectedVehicleType = type),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _vehicleNumberController,
                  textCapitalization: TextCapitalization.characters,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Vehicle number', hintText: 'TN45AB1234'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseNumberController,
                  textCapitalization: TextCapitalization.characters,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'License number'),
                ),
                const SizedBox(height: 28),
                AppButton(label: 'Submit for verification', onPressed: _submit, isLoading: _isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
