import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/food_model.dart';

/// Tracks the in-progress selection (variant, addons, quantity, notes) while
/// a customer is configuring a food item on the Food Details screen, before
/// adding it to the cart.
///
/// Pricing note: the backend's `pricing` field (discount + GST breakdown) is
/// computed against the food's *base* price only — variant selection isn't
/// threaded through the discount calculation server-side yet. When a variant
/// is selected we therefore show `variant.price + GST` (GST is safe to
/// recompute client-side since `gst_rate` is a flat percentage) but do not
/// attempt to re-apply a discount to it.
class FoodSelectionState extends Equatable {
  final FoodModel food;
  final FoodVariantModel? selectedVariant;
  final Map<String, int> addonQuantities;
  final int quantity;
  final String notes;

  const FoodSelectionState({
    required this.food,
    this.selectedVariant,
    this.addonQuantities = const {},
    this.quantity = 1,
    this.notes = '',
  });

  double get unitBasePrice {
    final variant = selectedVariant;
    if (variant != null) {
      final gstAmount = variant.price * food.gstRate / 100;
      return variant.price + gstAmount;
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

  double get totalPrice => unitTotalPrice * quantity;

  bool get canIncreaseQuantity => quantity < 20;
  bool get canDecreaseQuantity => quantity > 1;

  FoodSelectionState copyWith({
    FoodVariantModel? selectedVariant,
    Map<String, int>? addonQuantities,
    int? quantity,
    String? notes,
  }) {
    return FoodSelectionState(
      food: food,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      addonQuantities: addonQuantities ?? this.addonQuantities,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [food, selectedVariant, addonQuantities, quantity, notes];
}

class FoodSelectionNotifier extends FamilyNotifier<FoodSelectionState, FoodModel> {
  @override
  FoodSelectionState build(FoodModel arg) {
    return FoodSelectionState(food: arg, selectedVariant: arg.defaultVariant);
  }

  void selectVariant(FoodVariantModel variant) => state = state.copyWith(selectedVariant: variant);

  void setAddonQuantity(String addonId, int quantity) {
    final updated = Map<String, int>.from(state.addonQuantities);
    if (quantity <= 0) {
      updated.remove(addonId);
    } else {
      updated[addonId] = quantity;
    }
    state = state.copyWith(addonQuantities: updated);
  }

  void incrementQuantity() {
    if (state.canIncreaseQuantity) state = state.copyWith(quantity: state.quantity + 1);
  }

  void decrementQuantity() {
    if (state.canDecreaseQuantity) state = state.copyWith(quantity: state.quantity - 1);
  }

  void setNotes(String notes) => state = state.copyWith(notes: notes);
}

final foodSelectionProvider = NotifierProvider.family<FoodSelectionNotifier, FoodSelectionState, FoodModel>(
  FoodSelectionNotifier.new,
);
