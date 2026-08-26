import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/business_hours_model.dart';
import '../providers/restaurant_provider.dart';

class BusinessHoursScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const BusinessHoursScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends ConsumerState<BusinessHoursScreen> {
  List<BusinessHoursEntry>? _draft;
  bool _isSaving = false;

  List<BusinessHoursEntry> _ensureAllDays(List<BusinessHoursEntry> loaded) {
    final byDay = {for (final entry in loaded) entry.dayOfWeek: entry};
    return [
      for (var day = 0; day < 7; day++)
        byDay[day] ?? BusinessHoursEntry(dayOfWeek: day, openingTime: '09:00', closingTime: '22:00', isClosed: true),
    ];
  }

  Future<void> _pickTime(BuildContext context, String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (_draft == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(businessHoursProvider(widget.restaurantId).notifier).save(_draft!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business hours updated')));
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoursAsync = ref.watch(businessHoursProvider(widget.restaurantId));

    return Scaffold(
      appBar: AppBar(title: const Text('Business Hours')),
      body: hoursAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.invalidate(businessHoursProvider(widget.restaurantId)),
        ),
        data: (loaded) {
          _draft ??= _ensureAllDays(loaded);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Customers only see your restaurant as "open" during these hours.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _draft!.length; i++) _DayRow(
                entry: _draft![i],
                onToggleClosed: (closed) => setState(() => _draft![i] = _draft![i].copyWith(isClosed: closed)),
                onPickOpening: () => _pickTime(context, _draft![i].openingTime, (t) => setState(() => _draft![i] = _draft![i].copyWith(openingTime: t))),
                onPickClosing: () => _pickTime(context, _draft![i].closingTime, (t) => setState(() => _draft![i] = _draft![i].copyWith(closingTime: t))),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Save hours', onPressed: _save, isLoading: _isSaving),
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final BusinessHoursEntry entry;
  final ValueChanged<bool> onToggleClosed;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  const _DayRow({
    required this.entry,
    required this.onToggleClosed,
    required this.onPickOpening,
    required this.onPickClosing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(weekdayNames[entry.dayOfWeek], style: AppTextStyles.bodyMedium)),
          Expanded(
            child: entry.isClosed
                ? Text('Closed', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
                : Row(
                    children: [
                      TextButton(onPressed: onPickOpening, child: Text(entry.openingTime)),
                      const Text('–'),
                      TextButton(onPressed: onPickClosing, child: Text(entry.closingTime)),
                    ],
                  ),
          ),
          Switch(
            activeThumbColor: AppColors.primary,
            value: !entry.isClosed,
            onChanged: (open) => onToggleClosed(!open),
          ),
        ],
      ),
    );
  }
}
