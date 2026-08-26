import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/address_model.dart';
import '../providers/address_provider.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final address = AddressModel(
        id: '',
        label: _labelController.text.trim(),
        addressLine1: _line1Controller.text.trim(),
        addressLine2: _line2Controller.text.trim().isEmpty ? null : _line2Controller.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: 0,
        longitude: 0,
        isDefault: false,
      );
      await ref.read(addressListProvider.notifier).createAddress(address);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Address')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _labelController,
                label: 'Label (e.g. Home, Work)',
                validator: (value) => Validators.required(value, fieldName: 'Label'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _line1Controller,
                label: 'Address line 1',
                validator: (value) => Validators.required(value, fieldName: 'Address line 1'),
              ),
              const SizedBox(height: 16),
              AppTextField(controller: _line2Controller, label: 'Address line 2 (optional)'),
              const SizedBox(height: 16),
              AppTextField(
                controller: _cityController,
                label: 'City',
                validator: (value) => Validators.required(value, fieldName: 'City'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _stateController,
                label: 'State',
                validator: (value) => Validators.required(value, fieldName: 'State'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _pincodeController,
                label: 'Pincode',
                keyboardType: TextInputType.number,
                validator: (value) => Validators.pincode(value),
              ),
              const SizedBox(height: 32),
              AppButton(label: 'Save address', isLoading: _isSaving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
