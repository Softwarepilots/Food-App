import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Live "Accept within: 00:45" countdown shown on a newly placed order,
/// counting down to [deadline]. Turns red inside the last 30 seconds so it's
/// impossible to miss before the backend's lazy-expiry sweep auto-rejects it.
class AcceptCountdown extends StatefulWidget {
  final DateTime deadline;

  const AcceptCountdown({super.key, required this.deadline});

  @override
  State<AcceptCountdown> createState() => _AcceptCountdownState();
}

class _AcceptCountdownState extends State<AcceptCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.deadline.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.deadline.difference(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds;
    if (seconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text('Expiring…', style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
      );
    }
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final label = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isUrgent = seconds <= 30;
    final color = isUrgent ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text('Accept within $label', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
