import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic> _fieldErrors = const {};

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _serverError(String field) {
    final error = _fieldErrors[field];
    if (error == null) return null;
    if (error is List && error.isNotEmpty) return error.first.toString();
    return error.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _fieldErrors = const {};
    });
    try {
      await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            fullName: _fullNameController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      setState(() => _fieldErrors = failure.fieldErrors);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partner with Garuda', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Register your restaurant to start receiving orders.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _fullNameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                  decoration: const InputDecoration(labelText: 'Your full name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : _serverError('email'),
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : _serverError('phone_number'),
                  decoration: const InputDecoration(labelText: 'Phone number', hintText: '+919876543210', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                ),
                const SizedBox(height: 24),
                AppButton(label: 'Create account', onPressed: _submit, isLoading: _isSubmitting),
                const SizedBox(height: 16),
                Text(
                  "After signing up, you'll add your restaurant details from Settings.",
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
