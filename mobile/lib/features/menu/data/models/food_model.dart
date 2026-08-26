import 'package:equatable/equatable.dart';

double _parseDecimal(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

class PricingModel extends Equatable {
  final double unitPrice;
  final double discountAmount;
  final double priceAfterDiscount;
  final double gstRate;
  final double gstAmount;
  final double finalPrice;

  const PricingModel({
    required this.unitPrice,
    required this.discountAmount,
    required this.priceAfterDiscount,
    required this.gstRate,
    required this.gstAmount,
    required this.finalPrice,
  });

  factory PricingModel.fromJson(Map<String, dynamic> json) => PricingModel(
        unitPrice: _parseDecimal(json['unit_price']),
        discountAmount: _parseDecimal(json['discount_amount']),
        priceAfterDiscount: _parseDecimal(json['price_after_discount']),
        gstRate: _parseDecimal(json['gst_rate']),
        gstAmount: _parseDecimal(json['gst_amount']),
        finalPrice: _parseDecimal(json['final_price']),
      );

  bool get hasDiscount => discountAmount > 0;

  @override
  List<Object?> get props => [unitPrice, discountAmount, priceAfterDiscount, gstRate, gstAmount, finalPrice];
}

class FoodVariantModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isDefault;
  final bool isAvailable;
  final bool isInStock;
  final bool isOrderable;

  const FoodVariantModel({
    required this.id,
    required this.name,
    required this.price,
    required this.isDefault,
    required this.isAvailable,
    required this.isInStock,
    required this.isOrderable,
  });

  factory FoodVariantModel.fromJson(Map<String, dynamic> json) => FoodVariantModel(
        id: json['id'] as String,
        name: json['name'] as String,
        price: _parseDecimal(json['price']),
        isDefault: json['is_default'] as bool? ?? false,
        isAvailable: json['is_available'] as bool? ?? true,
        isInStock: json['is_in_stock'] as bool? ?? true,
        isOrderable: json['is_orderable'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name, price, isDefault, isAvailable, isInStock, isOrderable];
}

class FoodAddonModel extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;
  final int maxQuantity;

  const FoodAddonModel({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.maxQuantity,
  });

  factory FoodAddonModel.fromJson(Map<String, dynamic> json) => FoodAddonModel(
        id: json['id'] as String,
        name: json['name'] as String,
        price: _parseDecimal(json['price']),
        isAvailable: json['is_available'] as bool? ?? true,
        maxQuantity: json['max_quantity'] as int? ?? 1,
      );

  @override
  List<Object?> get props => [id, name, price, isAvailable, maxQuantity];
}

class FoodModel extends Equatable {
  final String id;
  final String? categoryId;
  final String name;
  final String? description;
  final String imageUrl;
  final String? primaryImageUrl;
  final String foodType;
  final double basePrice;
  final double gstRate;
  final PricingModel pricing;
  final bool isAvailable;
  final bool isBestseller;
  final bool isInStock;
  final bool isOrderable;
  final int? calories;
  final int preparationTimeMinutes;
  final double averageRating;
  final int totalReviews;
  final List<FoodVariantModel> variants;
  final List<FoodAddonModel> addons;

  const FoodModel({
    required this.id,
    this.categoryId,
    required this.name,
    this.description,
    required this.imageUrl,
    this.primaryImageUrl,
    required this.foodType,
    required this.basePrice,
    required this.gstRate,
    required this.pricing,
    required this.isAvailable,
    required this.isBestseller,
    required this.isInStock,
    required this.isOrderable,
    this.calories,
    required this.preparationTimeMinutes,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.variants = const [],
    this.addons = const [],
  });

  factory FoodModel.fromJson(Map<String, dynamic> json) => FoodModel(
        id: json['id'] as String,
        categoryId: json['category'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String? ?? '',
        primaryImageUrl: json['primary_image_url'] as String?,
        foodType: json['food_type'] as String? ?? 'veg',
        basePrice: _parseDecimal(json['base_price']),
        gstRate: _parseDecimal(json['gst_rate']),
        pricing: json['pricing'] != null
            ? PricingModel.fromJson(json['pricing'] as Map<String, dynamic>)
            : PricingModel(
                unitPrice: _parseDecimal(json['base_price']),
                discountAmount: 0,
                priceAfterDiscount: _parseDecimal(json['base_price']),
                gstRate: _parseDecimal(json['gst_rate']),
                gstAmount: 0,
                finalPrice: _parseDecimal(json['base_price']),
              ),
        isAvailable: json['is_available'] as bool? ?? true,
        isBestseller: json['is_bestseller'] as bool? ?? false,
        isInStock: json['is_in_stock'] as bool? ?? true,
        isOrderable: json['is_orderable'] as bool? ?? true,
        calories: json['calories'] as int?,
        preparationTimeMinutes: json['preparation_time_minutes'] as int? ?? 15,
        averageRating: _parseDecimal(json['average_rating']),
        totalReviews: json['total_reviews'] as int? ?? 0,
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((e) => FoodVariantModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        addons: (json['addons'] as List<dynamic>? ?? [])
            .map((e) => FoodAddonModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get displayImageUrl => (primaryImageUrl != null && primaryImageUrl!.isNotEmpty) ? primaryImageUrl! : imageUrl;

  bool get isVeg => foodType == 'veg' || foodType == 'vegan';

  FoodVariantModel? get defaultVariant {
    if (variants.isEmpty) return null;
    for (final variant in variants) {
      if (variant.isDefault) return variant;
    }
    return variants.first;
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        name,
        description,
        imageUrl,
        primaryImageUrl,
        foodType,
        basePrice,
        gstRate,
        pricing,
        isAvailable,
        isBestseller,
        isInStock,
        isOrderable,
        calories,
        preparationTimeMinutes,
        averageRating,
        totalReviews,
        variants,
        addons,
      ];
}

class FoodReviewModel extends Equatable {
  final String id;
  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const FoodReviewModel({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory FoodReviewModel.fromJson(Map<String, dynamic> json) => FoodReviewModel(
        id: json['id'] as String,
        userName: json['user_name'] as String? ?? 'Garuda user',
        rating: json['rating'] as int? ?? 0,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, userName, rating, comment, createdAt];
}

class MenuCategoryModel extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final List<FoodModel> foods;

  const MenuCategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.foods,
  });

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) => MenuCategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        foods: (json['foods'] as List<dynamic>? ?? []).map((e) => FoodModel.fromJson(e as Map<String, dynamic>)).toList(),
      );

  @override
  List<Object?> get props => [id, name, sortOrder, foods];
}

class RestaurantMenuModel extends Equatable {
  final String restaurantId;
  final List<MenuCategoryModel> categories;
  final List<FoodModel> uncategorized;

  const RestaurantMenuModel({
    required this.restaurantId,
    required this.categories,
    this.uncategorized = const [],
  });

  factory RestaurantMenuModel.fromJson(Map<String, dynamic> json) => RestaurantMenuModel(
        restaurantId: json['restaurant_id'] as String,
        categories:
            (json['categories'] as List<dynamic>? ?? []).map((e) => MenuCategoryModel.fromJson(e as Map<String, dynamic>)).toList(),
        uncategorized:
            (json['uncategorized'] as List<dynamic>? ?? []).map((e) => FoodModel.fromJson(e as Map<String, dynamic>)).toList(),
      );

  bool get isEmpty => categories.every((c) => c.foods.isEmpty) && uncategorized.isEmpty;

  @override
  List<Object?> get props => [restaurantId, categories, uncategorized];
}
