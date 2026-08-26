import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Stylized stand-in for a live map — a route illustration between the
/// restaurant and the delivery address. Not a real map (no live GPS); swap
/// for an actual maps SDK integration if one is wired up later.
class DeliveryRoutePreview extends StatelessWidget {
  const DeliveryRoutePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
          const Positioned(
            left: 24,
            bottom: 20,
            child: _RoutePin(color: AppColors.primary, icon: Icons.storefront),
          ),
          const Positioned(
            right: 24,
            top: 20,
            child: _RoutePin(color: AppColors.secondaryDark, icon: Icons.location_on),
          ),
        ],
      ),
    );
  }
}

class _RoutePin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _RoutePin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..cubicTo(
        size.width * 0.30, size.height * 0.55,
        size.width * 0.35, size.height * 0.85,
        size.width * 0.52, size.height * 0.60,
      )
      ..cubicTo(
        size.width * 0.68, size.height * 0.38,
        size.width * 0.72, size.height * 0.55,
        size.width * 0.84, size.height * 0.22,
      );

    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
