import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

class FoodModel extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final double basePrice;
  final String foodType;
  final bool isAvailable;
  final bool isBestseller;
  final double averageRating;
  final int totalReviews;

  const FoodModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.basePrice,
    required this.foodType,
    required this.isAvailable,
    required this.isBestseller,
    required this.averageRating,
    required this.totalReviews,
  });

  factory FoodModel.fromJson(Map<String, dynamic> json) => FoodModel(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: (json['primary_image_url'] as String?) ?? (json['image_url'] as String? ?? ''),
        basePrice: _parseDecimal(json['base_price']),
        foodType: json['food_type'] as String? ?? 'veg',
        isAvailable: json['is_available'] as bool? ?? true,
        isBestseller: json['is_bestseller'] as bool? ?? false,
        averageRating: _parseDecimal(json['average_rating']),
        totalReviews: json['total_reviews'] as int? ?? 0,
      );

  bool get isVeg => foodType == 'veg' || foodType == 'vegan';

  FoodModel copyWith({bool? isAvailable}) => FoodModel(
        id: id,
        name: name,
        imageUrl: imageUrl,
        basePrice: basePrice,
        foodType: foodType,
        isAvailable: isAvailable ?? this.isAvailable,
        isBestseller: isBestseller,
        averageRating: averageRating,
        totalReviews: totalReviews,
      );

  @override
  List<Object?> get props => [id, name, imageUrl, basePrice, foodType, isAvailable, isBestseller, averageRating, totalReviews];
}
