import 'package:flutter/material.dart';
import '../error/failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure.isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 56,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              failure.isNetworkError ? 'You\'re offline' : 'Something went wrong',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              failure.message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 160,
                child: AppButton(label: 'Try again', onPressed: onRetry, variant: AppButtonVariant.outlined),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
