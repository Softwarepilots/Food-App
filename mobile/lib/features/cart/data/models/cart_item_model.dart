import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../menu/data/models/food_model.dart';

const _uuid = Uuid();

/// One line in the local cart. Cart state lives entirely on-device (see
/// `cart_provider.dart`) — there is no backend cart API yet, which matches
/// how most food-delivery apps work in practice anyway (cart is ephemeral
/// until checkout creates the order).
class CartItemModel extends Equatable {
  final String lineId;
  final String restaurantId;
  final String restaurantName;
  final FoodModel food;
  final FoodVariantModel? variant;
  final Map<String, int> addonQuantities;
  final int quantity;
  final String notes;

  CartItemModel({
    String? lineId,
    required this.restaurantId,
    required this.restaurantName,
    required this.food,
    this.variant,
    this.addonQuantities = const {},
    required this.quantity,
    this.notes = '',
  }) : lineId = lineId ?? _uuid.v4();

  double get unitBasePrice {
    final v = variant;
    if (v != null) {
      final gstAmount = v.price * food.gstRate / 100;
      return v.price + gstAmount;
    }
    return food.pricing.finalPrice;
  }

  double get addonsTotal {
    double total = 0;
    for (final addon in food.addons) {
      final qty = addonQuantities[addon.id] ?? 0;
      total += addon.price * qty;
    }
    return total;
  }

  double get unitTotalPrice => unitBasePrice + addonsTotal;

  double get lineTotal => unitTotalPrice * quantity;

  List<FoodAddonModel> get selectedAddons =>
      food.addons.where((a) => (addonQuantities[a.id] ?? 0) > 0).toList();

  /// Same food + variant + addons + notes combination — used to merge
  /// duplicate additions instead of creating a separate line.
  bool matchesSelection(CartItemModel other) {
    return food.id == other.food.id &&
        variant?.id == other.variant?.id &&
        notes == other.notes &&
        const MapEquality().equals(addonQuantities, other.addonQuantities);
  }

  CartItemModel copyWith({int? quantity}) {
    return CartItemModel(
      lineId: lineId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      food: food,
      variant: variant,
      addonQuantities: addonQuantities,
      quantity: quantity ?? this.quantity,
      notes: notes,
    );
  }

  @override
  List<Object?> get props => [lineId, restaurantId, food, variant, addonQuantities, quantity, notes];
}

/// Minimal map-equality helper (avoids pulling in `collection` just for this).
class MapEquality {
  const MapEquality();

  bool equals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
