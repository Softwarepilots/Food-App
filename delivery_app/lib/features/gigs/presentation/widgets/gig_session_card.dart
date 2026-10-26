import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/shift_model.dart';

String _formatHour12(int hour) {
  final period = hour >= 12 ? 'pm' : 'am';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:00$period';
}

String _formatTime(DateTime time) {
  final period = time.hour >= 12 ? 'pm' : 'am';
  final h12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$h12:$minute$period';
}

IconData _sessionIcon(GigSession session) {
  switch (session) {
    case GigSession.lunch:
      return Icons.wb_sunny_rounded;
    case GigSession.evening:
      return Icons.wb_twilight_rounded;
    case GigSession.dinner:
      return Icons.nightlight_round;
  }
}

Color _sessionIconColor(GigSession session) {
  switch (session) {
    case GigSession.lunch:
      return AppColors.secondary;
    case GigSession.evening:
      return const Color(0xFFFF8A4C);
    case GigSession.dinner:
      return const Color(0xFF8C9EFF);
  }
}

/// One Swiggy-style "gigs" group: a black header naming the session
/// ("Lunch Gigs", its window, and how many slots it has) followed by each
/// slot as a white row with its hourly rate range, a star on peak slots,
/// and a trailing control (checkbox to select, or a cancel action) that the
/// caller supplies so this one card works for both the browse and
/// already-booked views.
class GigSessionCard extends StatelessWidget {
  final GigSession session;
  final List<ShiftModel> shifts;
  final Widget Function(ShiftModel shift) trailingBuilder;

  const GigSessionCard({super.key, required this.session, required this.shifts, required this.trailingBuilder});

  @override
  Widget build(BuildContext context) {
    final (startHour, endHour) = session.hourRange;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.label,
                        style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatHour12(startHour)} - ${_formatHour12(endHour)} • ${shifts.length} Gigs',
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(_sessionIcon(session), color: _sessionIconColor(session), size: 28),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                for (var i = 0; i < shifts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _SlotRow(shift: shifts[i], trailing: trailingBuilder(shifts[i])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final ShiftModel shift;
  final Widget trailing;

  const _SlotRow({required this.shift, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatTime(shift.startsAt)} - ${_formatTime(shift.endsAt)}',
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${shift.rateMinPerHour.toStringAsFixed(0)} - ₹${shift.rateMaxPerHour.toStringAsFixed(0)} per hour',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                if (shift.isPeak) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.star_rounded, size: 18, color: AppColors.textPrimary),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}
