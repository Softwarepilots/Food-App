import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shown while [AuthNotifier] restores the session from secure storage.
/// The router's redirect logic (which watches auth state) navigates away
/// automatically once the check completes — this screen has no logic of
/// its own beyond branding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _spinnerOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 1.1,
            colors: [AppColors.primaryDark, Color(0xFF0A0503), Colors.black],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(_logoScale),
                  child: Image.asset('assets/images/logo.png', width: 260, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _spinnerOpacity,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
