import 'package:equatable/equatable.dart';

/// Parses a backend DecimalField, which DRF serializes as a JSON string
/// (e.g. "13.082700") by default rather than a number.
double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? _parseNullableDecimal(dynamic value) {
  if (value == null) return null;
  return _parseDecimal(value);
}

class RestaurantCategoryModel extends Equatable {
  final String id;
  final String name;
  final String? iconUrl;

  const RestaurantCategoryModel({required this.id, required this.name, this.iconUrl});

  factory RestaurantCategoryModel.fromJson(Map<String, dynamic> json) => RestaurantCategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        iconUrl: (json['icon_url'] as String?)?.isNotEmpty == true ? json['icon_url'] as String : null,
      );

  @override
  List<Object?> get props => [id, name, iconUrl];
}

class BusinessHoursModel extends Equatable {
  final int dayOfWeek;
  final String? openingTime;
  final String? closingTime;
  final bool isClosed;

  const BusinessHoursModel({
    required this.dayOfWeek,
    this.openingTime,
    this.closingTime,
    required this.isClosed,
  });

  factory BusinessHoursModel.fromJson(Map<String, dynamic> json) => BusinessHoursModel(
        dayOfWeek: json['day_of_week'] as int,
        openingTime: json['opening_time'] as String?,
        closingTime: json['closing_time'] as String?,
        isClosed: json['is_closed'] as bool? ?? false,
      );

  static const List<String> dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get dayName => dayNames[dayOfWeek % 7];

  @override
  List<Object?> get props => [dayOfWeek, openingTime, closingTime, isClosed];
}

class RestaurantImageModel extends Equatable {
  final String id;
  final String imageUrl;
  final bool isPrimary;

  const RestaurantImageModel({required this.id, required this.imageUrl, required this.isPrimary});

  factory RestaurantImageModel.fromJson(Map<String, dynamic> json) => RestaurantImageModel(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String,
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, imageUrl, isPrimary];
}

class RestaurantModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String coverImageUrl;
  final String? primaryImageUrl;
  final List<String> cuisineTags;
  final List<RestaurantCategoryModel> categories;
  final String? addressLine;
  final String city;
  final double latitude;
  final double longitude;
  final double deliveryRadiusKm;
  final int avgPrepTimeMinutes;
  final double averageRating;
  final int totalReviews;
  final String displayStatus;
  final bool? isOpenNow;
  final double? distanceKm;
  final List<RestaurantImageModel> images;
  final List<BusinessHoursModel> businessHours;
  final bool isFavorite;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.coverImageUrl,
    this.primaryImageUrl,
    required this.cuisineTags,
    required this.categories,
    this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.deliveryRadiusKm,
    required this.avgPrepTimeMinutes,
    required this.averageRating,
    required this.totalReviews,
    required this.displayStatus,
    this.isOpenNow,
    this.distanceKm,
    this.images = const [],
    this.businessHours = const [],
    this.isFavorite = false,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) => RestaurantModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String?,
        coverImageUrl: json['cover_image_url'] as String? ?? '',
        primaryImageUrl: json['primary_image_url'] as String?,
        cuisineTags: (json['cuisine_tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => RestaurantCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        addressLine: json['address_line'] as String?,
        city: json['city'] as String? ?? '',
        latitude: _parseDecimal(json['latitude']),
        longitude: _parseDecimal(json['longitude']),
        deliveryRadiusKm: _parseDecimal(json['delivery_radius_km'], fallback: 5),
        avgPrepTimeMinutes: json['avg_prep_time_minutes'] as int? ?? 30,
        averageRating: _parseDecimal(json['average_rating']),
        totalReviews: json['total_reviews'] as int? ?? 0,
        displayStatus: json['display_status'] as String? ?? 'closed',
        isOpenNow: json['is_open_now'] as bool?,
        distanceKm: _parseNullableDecimal(json['distance_km']),
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => RestaurantImageModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        businessHours: (json['business_hours'] as List<dynamic>? ?? [])
            .map((e) => BusinessHoursModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        isFavorite: json['is_favorite'] as bool? ?? false,
      );

  RestaurantModel copyWith({bool? isFavorite}) => RestaurantModel(
        id: id,
        name: name,
        slug: slug,
        description: description,
        coverImageUrl: coverImageUrl,
        primaryImageUrl: primaryImageUrl,
        cuisineTags: cuisineTags,
        categories: categories,
        addressLine: addressLine,
        city: city,
        latitude: latitude,
        longitude: longitude,
        deliveryRadiusKm: deliveryRadiusKm,
        avgPrepTimeMinutes: avgPrepTimeMinutes,
        averageRating: averageRating,
        totalReviews: totalReviews,
        displayStatus: displayStatus,
        isOpenNow: isOpenNow,
        distanceKm: distanceKm,
        images: images,
        businessHours: businessHours,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  String get displayImageUrl {
    if (primaryImageUrl != null && primaryImageUrl!.isNotEmpty) return primaryImageUrl!;
    if (images.isNotEmpty) {
      final primary = images.where((i) => i.isPrimary).firstOrNull;
      if (primary != null) return primary.imageUrl;
      return images.first.imageUrl;
    }
    return coverImageUrl;
  }

  bool get isOpen => displayStatus == 'open';
  bool get isPendingApproval => displayStatus == 'pending';

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        coverImageUrl,
        primaryImageUrl,
        cuisineTags,
        categories,
        addressLine,
        city,
        latitude,
        longitude,
        deliveryRadiusKm,
        avgPrepTimeMinutes,
        averageRating,
        totalReviews,
        displayStatus,
        isOpenNow,
        distanceKm,
        images,
        businessHours,
        isFavorite,
      ];
}

class RatingBreakdownModel extends Equatable {
  final double averageRating;
  final int totalReviews;
  final Map<String, int> breakdown;

  const RatingBreakdownModel({
    required this.averageRating,
    required this.totalReviews,
    required this.breakdown,
  });

  factory RatingBreakdownModel.fromJson(Map<String, dynamic> json) => RatingBreakdownModel(
        averageRating: _parseDecimal(json['average_rating']),
        totalReviews: json['total_reviews'] as int? ?? 0,
        breakdown: (json['breakdown'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v as int)),
      );

  @override
  List<Object?> get props => [averageRating, totalReviews, breakdown];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
