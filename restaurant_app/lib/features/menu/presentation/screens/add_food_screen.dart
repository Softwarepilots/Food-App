import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/menu_provider.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const AddFoodScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _foodType = 'veg';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(menuProvider(widget.restaurantId).notifier).addFood(
            name: _nameController.text.trim(),
            basePrice: double.parse(_priceController.text.trim()),
            foodType: _foodType,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add dish')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Dish name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return double.tryParse(v.trim()) == null ? 'Enter a valid price' : null;
                  },
                  decoration: const InputDecoration(labelText: 'Price (₹)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _foodType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'veg', child: Text('Vegetarian')),
                    DropdownMenuItem(value: 'non_veg', child: Text('Non-Vegetarian')),
                    DropdownMenuItem(value: 'egg', child: Text('Contains Egg')),
                    DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                  ],
                  onChanged: (value) => setState(() => _foodType = value ?? 'veg'),
                ),
                const SizedBox(height: 28),
                AppButton(label: 'Add dish', onPressed: _submit, isLoading: _isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
