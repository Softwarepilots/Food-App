import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

const _presets = [15, 20, 25, 30, 40, 45];

/// §8's "Set preparation time" step, shown right before an order is
/// accepted. Returns the chosen minutes, or null if the owner backed out.
Future<int?> showPrepTimePicker(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => const _PrepTimePickerSheet(),
  );
}

class _PrepTimePickerSheet extends StatefulWidget {
  const _PrepTimePickerSheet();

  @override
  State<_PrepTimePickerSheet> createState() => _PrepTimePickerSheetState();
}

class _PrepTimePickerSheetState extends State<_PrepTimePickerSheet> {
  int? _selected;
  final _customController = TextEditingController();
  bool _customSelected = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_customSelected) {
      final minutes = int.tryParse(_customController.text.trim());
      if (minutes == null || minutes < 1 || minutes > 180) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter minutes between 1 and 180')));
        return;
      }
      Navigator.of(context).pop(minutes);
      return;
    }
    if (_selected != null) Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set preparation time', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'How long will this order take to prepare?',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final minutes in _presets)
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: !_customSelected && _selected == minutes,
                  onSelected: (_) => setState(() {
                    _customSelected = false;
                    _selected = minutes;
                  }),
                  selectedColor: AppColors.primary,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    color: !_customSelected && _selected == minutes ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _customSelected,
                onSelected: (_) => setState(() => _customSelected = true),
                selectedColor: AppColors.primary,
                labelStyle: AppTextStyles.bodyMedium.copyWith(
                  color: _customSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_customSelected) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Minutes', suffixText: 'min'),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(label: 'Accept order', onPressed: _confirm),
        ],
      ),
    );
  }
}
