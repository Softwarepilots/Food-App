import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Garuda logo artwork has a solid (non-transparent) dark background, so
/// it needs a matching dark card behind it rather than sitting directly on a
/// light screen background — this wraps it consistently everywhere it's used
/// outside the full-bleed splash screen.
class LogoBadge extends StatelessWidget {
  final double width;
  final double height;

  const LogoBadge({super.key, this.width = 220, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.2,
          colors: [AppColors.primaryDark, Color(0xFF0A0503), Colors.black],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}
