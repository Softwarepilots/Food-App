import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item_model.dart';

/// Thrown when trying to add an item from a different restaurant than what's
/// already in the cart — the UI should catch this and offer to clear the
/// cart first (mirrors the backend's single-restaurant-cart business rule).
class DifferentRestaurantException implements Exception {
  final String existingRestaurantName;
  const DifferentRestaurantException(this.existingRestaurantName);
}

class CartState {
  final List<CartItemModel> items;

  const CartState({this.items = const []});

  String? get restaurantId => items.isEmpty ? null : items.first.restaurantId;
  String? get restaurantName => items.isEmpty ? null : items.first.restaurantName;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItemModel>? items}) => CartState(items: items ?? this.items);
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds [item] to the cart, merging into an existing identical line if one
  /// exists. Throws [DifferentRestaurantException] if the cart already holds
  /// items from a different restaurant — callers should confirm with the
  /// user, call [clear], then retry.
  void addItem(CartItemModel item) {
    if (state.items.isNotEmpty && state.restaurantId != item.restaurantId) {
      throw DifferentRestaurantException(state.restaurantName!);
    }

    final existingIndex = state.items.indexWhere((existing) => existing.matchesSelection(item));
    if (existingIndex != -1) {
      final existing = state.items[existingIndex];
      final updated = [...state.items];
      updated[existingIndex] = existing.copyWith(quantity: existing.quantity + item.quantity);
      state = state.copyWith(items: updated);
      return;
    }

    state = state.copyWith(items: [...state.items, item]);
  }

  void updateQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      removeItem(lineId);
      return;
    }
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.lineId == lineId) item.copyWith(quantity: quantity) else item,
      ],
    );
  }

  void removeItem(String lineId) {
    state = state.copyWith(items: state.items.where((item) => item.lineId != lineId).toList());
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
