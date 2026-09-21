import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../menu/presentation/widgets/veg_indicator.dart';

/// Compact veg/non-veg toggle, styled like Swiggy's — a small pill with two
/// tappable squares. Tapping a segment filters to it; tapping the active
/// segment again clears back to "all". `value` is `null`/`''` for "all",
/// `'veg'`, or `'non_veg'`.
class VegToggle extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const VegToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = (value == null || value!.isEmpty) ? null : value;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VegToggleSegment(
            isVeg: true,
            selected: current == 'veg',
            onTap: () => onChanged(current == 'veg' ? null : 'veg'),
          ),
          _VegToggleSegment(
            isVeg: false,
            selected: current == 'non_veg',
            onTap: () => onChanged(current == 'non_veg' ? null : 'non_veg'),
          ),
        ],
      ),
    );
  }
}

class _VegToggleSegment extends StatelessWidget {
  final bool isVeg;
  final bool selected;
  final VoidCallback onTap;

  const _VegToggleSegment({required this.isVeg, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
        ),
        child: VegIndicator(isVeg: isVeg, size: 16),
      ),
    );
  }
}
