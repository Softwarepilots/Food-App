import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

/// Combines a "YYYY-MM-DD" date string with an "HH:mm:ss" time string into a
/// local DateTime — the backend sends date and time as separate fields since
/// a shift's date/start/end are plain Django DateField/TimeField, not one
/// combined timestamp.
DateTime _combine(String dateStr, String timeStr) {
  final date = DateTime.tryParse(dateStr) ?? DateTime.now();
  final parts = timeStr.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// A bookable work slot ("gig") — a rider commits to a time window upfront
/// for an hourly rate range, Swiggy-style, rather than only picking up
/// ad-hoc ready-for-pickup orders.
class ShiftModel extends Equatable {
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final double rateMinPerHour;
  final double rateMaxPerHour;
  final bool isPeak;
  final int capacity;
  final int bookedCount;
  final bool isFull;
  final bool isBookedByMe;

  const ShiftModel({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.rateMinPerHour,
    required this.rateMaxPerHour,
    required this.isPeak,
    required this.capacity,
    required this.bookedCount,
    required this.isFull,
    required this.isBookedByMe,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String? ?? '';
    return ShiftModel(
      id: json['id'] as String,
      startsAt: _combine(date, json['start_time'] as String? ?? '00:00:00'),
      endsAt: _combine(date, json['end_time'] as String? ?? '00:00:00'),
      rateMinPerHour: _parseDecimal(json['rate_min_per_hour']),
      rateMaxPerHour: _parseDecimal(json['rate_max_per_hour']),
      isPeak: json['is_peak'] as bool? ?? false,
      capacity: json['capacity'] as int? ?? 0,
      bookedCount: json['booked_count'] as int? ?? 0,
      isFull: json['is_full'] as bool? ?? false,
      isBookedByMe: json['is_booked_by_me'] as bool? ?? false,
    );
  }

  int get spotsLeft => (capacity - bookedCount).clamp(0, capacity);

  @override
  List<Object?> get props => [
        id,
        startsAt,
        endsAt,
        rateMinPerHour,
        rateMaxPerHour,
        isPeak,
        capacity,
        bookedCount,
        isFull,
        isBookedByMe,
      ];
}

enum GigSession { lunch, evening, dinner }

extension GigSessionX on GigSession {
  String get label {
    switch (this) {
      case GigSession.lunch:
        return 'Lunch Gigs';
      case GigSession.evening:
        return 'Evening Gigs';
      case GigSession.dinner:
        return 'Dinner Gigs';
    }
  }

  /// The fixed window each session covers — used both to label the group
  /// header and to bucket shifts into one of the three sessions by their
  /// `startsAt` hour.
  (int, int) get hourRange {
    switch (this) {
      case GigSession.lunch:
        return (11, 15);
      case GigSession.evening:
        return (15, 19);
      case GigSession.dinner:
        return (19, 24);
    }
  }
}

/// Buckets a flat shift list into the three fixed day-part sessions, in
/// session order, dropping empty sessions and keeping each session's shifts
/// ordered by start time (already the case from the backend, but `sort`
/// defends this screen's grouping regardless of API ordering).
Map<GigSession, List<ShiftModel>> groupShiftsBySession(List<ShiftModel> shifts) {
  final grouped = <GigSession, List<ShiftModel>>{};
  for (final session in GigSession.values) {
    final (start, end) = session.hourRange;
    final matches = shifts.where((s) => s.startsAt.hour >= start && s.startsAt.hour < end).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (matches.isNotEmpty) grouped[session] = matches;
  }
  return grouped;
}
