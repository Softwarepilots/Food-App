import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final bool isNewUser;

  const OtpVerifyScreen({super.key, required this.phoneNumber, required this.isNewUser});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(
            phoneNumber: widget.phoneNumber,
            otp: _otpController.text.trim(),
            fullName: widget.isNewUser ? _nameController.text.trim() : null,
          );
      // Navigation to home is handled by the router's redirect logic.
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authProvider.notifier).requestOtp(widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new OTP has been sent.')));
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isResending = false);
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
                Text('Verify your number', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter the ${AppConstants.otpLength}-digit code sent to ${widget.phoneNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: AppConstants.otpLength,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(letterSpacing: 12),
                  validator: (v) => Validators.otp(v, length: AppConstants.otpLength),
                  decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(_isResending ? 'Sending...' : 'Resend OTP'),
                  ),
                ),
                if (widget.isNewUser) ...[
                  const SizedBox(height: 12),
                  Text("What's your name?", style: AppTextStyles.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validators.required(v, fieldName: 'Full name'),
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AppButton(label: 'Verify & Continue', onPressed: _submit, isLoading: _isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
