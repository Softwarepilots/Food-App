import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Network image with a shimmer placeholder and a graceful fallback icon,
/// used everywhere the app renders a restaurant/food/user photo.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    if (url == null || url!.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          width: width,
          height: height,
          color: AppColors.chipBackground,
          child: const Icon(Icons.restaurant_rounded, color: AppColors.textDisabled),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: AppColors.chipBackground,
          highlightColor: AppColors.surface,
          child: Container(width: width, height: height, color: AppColors.chipBackground),
        ),
        errorWidget: (context, _, _) => Container(
          width: width,
          height: height,
          color: AppColors.chipBackground,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textDisabled),
        ),
      ),
    );
  }
}
