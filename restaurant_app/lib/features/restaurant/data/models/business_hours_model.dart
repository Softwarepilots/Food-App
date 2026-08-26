import 'package:equatable/equatable.dart';

const List<String> weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

class BusinessHoursEntry extends Equatable {
  final int dayOfWeek; // 0=Monday .. 6=Sunday, matches Python's date.weekday()
  final String openingTime; // "HH:MM"
  final String closingTime; // "HH:MM"
  final bool isClosed;

  const BusinessHoursEntry({
    required this.dayOfWeek,
    required this.openingTime,
    required this.closingTime,
    required this.isClosed,
  });

  factory BusinessHoursEntry.fromJson(Map<String, dynamic> json) => BusinessHoursEntry(
        dayOfWeek: json['day_of_week'] as int,
        openingTime: _trimSeconds(json['opening_time'] as String? ?? '09:00:00'),
        closingTime: _trimSeconds(json['closing_time'] as String? ?? '22:00:00'),
        isClosed: json['is_closed'] as bool? ?? false,
      );

  static String _trimSeconds(String hhmmss) => hhmmss.length >= 5 ? hhmmss.substring(0, 5) : hhmmss;

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'opening_time': '$openingTime:00',
        'closing_time': '$closingTime:00',
        'is_closed': isClosed,
      };

  BusinessHoursEntry copyWith({String? openingTime, String? closingTime, bool? isClosed}) => BusinessHoursEntry(
        dayOfWeek: dayOfWeek,
        openingTime: openingTime ?? this.openingTime,
        closingTime: closingTime ?? this.closingTime,
        isClosed: isClosed ?? this.isClosed,
      );

  @override
  List<Object?> get props => [dayOfWeek, openingTime, closingTime, isClosed];
}
