import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../menu/presentation/widgets/star_rating_input.dart';
import '../providers/order_detail_provider.dart';

/// Shown on a delivered order's detail screen — lets the customer rate the
/// restaurant and, if a rider handled this order, the delivery separately.
/// Resubmitting just updates the same review (matches the backend's
/// update_or_create-per-order semantics), so there's no need to track
/// "already reviewed" client-side.
class OrderReviewCard extends ConsumerStatefulWidget {
  final String orderId;
  final String? deliveryPartnerName;

  const OrderReviewCard({super.key, required this.orderId, this.deliveryPartnerName});

  @override
  ConsumerState<OrderReviewCard> createState() => _OrderReviewCardState();
}

class _OrderReviewCardState extends ConsumerState<OrderReviewCard> {
  int _rating = 0;
  int _deliveryRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tap a star to rate the restaurant')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(orderDetailProvider(widget.orderId).notifier).submitReview(
            rating: _rating,
            comment: _commentController.text.trim(),
            deliveryRating: widget.deliveryPartnerName != null && _deliveryRating > 0 ? _deliveryRating : null,
          );
      if (!mounted) return;
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
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
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text('Review submitted', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your order', style: AppTextStyles.titleMedium),
          const SizedBox(height: 10),
          Text('Food & restaurant', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          StarRatingInput(rating: _rating, onChanged: (v) => setState(() => _rating = v)),
          if (widget.deliveryPartnerName != null) ...[
            const SizedBox(height: 12),
            Text('Delivery by ${widget.deliveryPartnerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            StarRatingInput(rating: _deliveryRating, onChanged: (v) => setState(() => _deliveryRating = v)),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Share your thoughts (optional)'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
