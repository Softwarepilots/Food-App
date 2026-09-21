import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/restaurant_provider.dart';

/// Shown when the logged-in owner has no restaurant yet — a minimal form to
/// register one. Approval (`approval_status`) is admin-gated on the backend;
/// this just gets the restaurant into the "pending" queue.
class RestaurantSetupScreen extends ConsumerStatefulWidget {
  const RestaurantSetupScreen({super.key});

  @override
  ConsumerState<RestaurantSetupScreen> createState() => _RestaurantSetupScreenState();
}

class _RestaurantSetupScreenState extends ConsumerState<RestaurantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _panController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _gstController = TextEditingController();
  final _shopLicenseController = TextEditingController();
  bool _isSubmitting = false;

  static final _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final _fssaiPattern = RegExp(r'^\d{14}$');
  static final _gstPattern = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z\d]$');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _panController.dispose();
    _fssaiController.dispose();
    _gstController.dispose();
    _shopLicenseController.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _decimal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
  }

  String? _pan(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return _panPattern.hasMatch(v.trim().toUpperCase()) ? null : 'Format: ABCDE1234F';
  }

  String? _fssai(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return _fssaiPattern.hasMatch(v.trim()) ? null : 'Enter a valid 14-digit FSSAI number';
  }

  String? _gst(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    return _gstPattern.hasMatch(v.trim().toUpperCase()) ? null : 'Enter a valid 15-character GSTIN';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(myRestaurantProvider.notifier).createRestaurant(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            addressLine: _addressController.text.trim(),
            city: _cityController.text.trim(),
            latitude: double.parse(_latController.text.trim()),
            longitude: double.parse(_lngController.text.trim()),
            panNumber: _panController.text.trim().toUpperCase(),
            fssaiNumber: _fssaiController.text.trim(),
            shopLicenseNumber: _shopLicenseController.text.trim(),
            gstNumber: _gstController.text.trim().toUpperCase(),
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
    // once myRestaurantProvider updates, but that redirect isn't synchronous
    // with this callback returning — re-enabling the button in that gap let
    // an impatient second tap fire a duplicate create request.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your restaurant')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us about your restaurant. An admin will review and approve it before it goes live.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Restaurant name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: _decimal,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: _decimal,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Business compliance', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Required to operate a food business in India — an admin verifies these before approving your restaurant.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _panController,
                  textCapitalization: TextCapitalization.characters,
                  validator: _pan,
                  decoration: const InputDecoration(labelText: 'PAN number', hintText: 'ABCDE1234F'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fssaiController,
                  keyboardType: TextInputType.number,
                  validator: _fssai,
                  decoration: const InputDecoration(labelText: 'FSSAI license number', hintText: '14-digit number'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _shopLicenseController,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Shop / trade license number'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  validator: _gst,
                  decoration: const InputDecoration(labelText: 'GST number (optional)'),
                ),
                const SizedBox(height: 28),
                AppButton(label: 'Register restaurant', onPressed: _submit, isLoading: _isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
