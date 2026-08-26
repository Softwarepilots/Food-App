import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class _PromoBanner {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;

  const _PromoBanner({required this.title, required this.subtitle, required this.icon, required this.background});
}

/// Static, in-app promo carousel — Garuda has no offers/CMS backend yet, so
/// these are fixed brand banners rather than server-driven content. Swap for
/// a real `/offers/` feed if one is ever built.
const _banners = [
  _PromoBanner(
    title: 'Delicious Food\nDelivered Fast',
    subtitle: 'Good food. Fast. For you.',
    icon: Icons.delivery_dining,
    background: AppColors.primary,
  ),
  _PromoBanner(
    title: 'Free Delivery\nOn Your First Order',
    subtitle: 'Karaikal first, always.',
    icon: Icons.local_shipping_outlined,
    background: AppColors.primaryDark,
  ),
  _PromoBanner(
    title: 'Discover Local\nFavorites',
    subtitle: 'Supporting restaurants near you.',
    icon: Icons.storefront_outlined,
    background: Color(0xFF5C0016),
  ),
];

class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _banners.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  decoration: BoxDecoration(color: banner.background, borderRadius: BorderRadius.circular(18)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(banner.icon, size: 110, color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              banner.title,
                              style: AppTextStyles.titleLarge.copyWith(color: Colors.white, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            Text(banner.subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
