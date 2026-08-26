import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/menu_remote_datasource.dart';
import '../../data/models/food_model.dart';

final menuRemoteDataSourceProvider = Provider<MenuRemoteDataSource>((ref) {
  return MenuRemoteDataSource(ref.watch(dioProvider));
});

class MenuNotifier extends FamilyAsyncNotifier<List<FoodModel>, String> {
  @override
  Future<List<FoodModel>> build(String restaurantId) {
    return ref.watch(menuRemoteDataSourceProvider).getFoods(restaurantId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(menuRemoteDataSourceProvider).getFoods(arg));
  }

  Future<void> toggleAvailability(String foodId, bool isAvailable) async {
    final current = state.value;
    if (current == null) return;
    // Optimistic update, then reconcile with the server response.
    state = AsyncValue.data([
      for (final food in current) if (food.id == foodId) food.copyWith(isAvailable: isAvailable) else food,
    ]);
    try {
      final updated = await ref
          .read(menuRemoteDataSourceProvider)
          .setAvailability(restaurantId: arg, foodId: foodId, isAvailable: isAvailable);
      final latest = state.value;
      if (latest == null) return;
      state = AsyncValue.data([for (final food in latest) if (food.id == foodId) updated else food]);
    } catch (_) {
      final latest = state.value;
      if (latest == null) return;
      state = AsyncValue.data([
        for (final food in latest) if (food.id == foodId) food.copyWith(isAvailable: !isAvailable) else food,
      ]);
      rethrow;
    }
  }

  Future<void> addFood({required String name, required double basePrice, required String foodType}) async {
    final created = await ref
        .read(menuRemoteDataSourceProvider)
        .createFood(restaurantId: arg, name: name, basePrice: basePrice, foodType: foodType);
    final current = state.value ?? [];
    state = AsyncValue.data([...current, created]);
  }
}

final menuProvider = AsyncNotifierProvider.family<MenuNotifier, List<FoodModel>, String>(MenuNotifier.new);
