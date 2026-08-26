import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/restaurant_model.dart';

enum RestaurantSort { relevance, ratingHighToLow, deliveryTimeFastest, distanceNearest }

extension RestaurantSortX on RestaurantSort {
  String get label {
    switch (this) {
      case RestaurantSort.relevance:
        return 'Relevance';
      case RestaurantSort.ratingHighToLow:
        return 'Rating: High to low';
      case RestaurantSort.deliveryTimeFastest:
        return 'Delivery time';
      case RestaurantSort.distanceNearest:
        return 'Distance';
    }
  }

  /// Sorts a page of already-loaded restaurants. This only reorders what's
  /// currently fetched — there's no server-side sort param, so it isn't a
  /// true global sort across unfetched pages.
  List<RestaurantModel> apply(List<RestaurantModel> restaurants) {
    final sorted = [...restaurants];
    switch (this) {
      case RestaurantSort.relevance:
        break;
      case RestaurantSort.ratingHighToLow:
        sorted.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case RestaurantSort.deliveryTimeFastest:
        sorted.sort((a, b) => a.avgPrepTimeMinutes.compareTo(b.avgPrepTimeMinutes));
      case RestaurantSort.distanceNearest:
        sorted.sort((a, b) => (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    }
    return sorted;
  }
}

Future<RestaurantSort?> showRestaurantSortSheet(BuildContext context, RestaurantSort current) {
  return showModalBottomSheet<RestaurantSort>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Align(alignment: Alignment.centerLeft, child: Text('Sort by', style: AppTextStyles.titleLarge)),
              ),
              for (final option in RestaurantSort.values)
                RadioListTile<RestaurantSort>(
                  value: option,
                  groupValue: current,
                  activeColor: AppColors.primary,
                  title: Text(option.label, style: AppTextStyles.bodyMedium),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
