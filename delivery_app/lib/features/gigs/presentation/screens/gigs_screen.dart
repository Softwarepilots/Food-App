import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/shift_model.dart';
import '../providers/shift_list_provider.dart';
import '../widgets/gig_session_card.dart';

class GigsScreen extends ConsumerStatefulWidget {
  const GigsScreen({super.key});

  @override
  ConsumerState<GigsScreen> createState() => _GigsScreenState();
}

class _GigsScreenState extends ConsumerState<GigsScreen> {
  final Set<String> _selectedIds = {};
  bool _isBooking = false;
  String? _cancellingId;

  Future<void> _confirmSelected() async {
    setState(() => _isBooking = true);
    try {
      final count = _selectedIds.length;
      await ref.read(shiftListProvider.notifier).bookMultiple(_selectedIds);
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booked $count gig(s)!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Failure.fromException(e).message)));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _cancel(String shiftId) async {
    setState(() => _cancellingId = shiftId);
    try {
      await ref.read(shiftListProvider.notifier).cancel(shiftId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig cancelled.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Failure.fromException(e).message)));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Gigs'),
          bottom: const TabBar(tabs: [Tab(text: 'Available'), Tab(text: 'My Gigs')]),
        ),
        body: TabBarView(
          children: [_buildAvailableTab(state), _buildMyGigsTab(state)],
        ),
      ),
    );
  }

  Widget _buildAvailableTab(ShiftListState state) {
    if (state.isLoading && state.availableShifts.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.availableShifts.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(shiftListProvider.notifier).refresh());
    }
    if (state.availableShifts.isEmpty) {
      return const EmptyView(
        title: 'No gigs available',
        message: 'Check back later for bookable shifts.',
        icon: Icons.work_outline,
      );
    }

    final grouped = groupShiftsBySession(state.availableShifts);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(shiftListProvider.notifier).refresh(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _selectedIds.isEmpty ? 16 : 96),
            children: [
              for (final entry in grouped.entries) ...[
                GigSessionCard(
                  session: entry.key,
                  shifts: entry.value,
                  trailingBuilder: (shift) => _AvailableTrailing(
                    shift: shift,
                    selected: _selectedIds.contains(shift.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked) {
                          _selectedIds.add(shift.id);
                        } else {
                          _selectedIds.remove(shift.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isBooking ? null : _confirmSelected,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isBooking
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('Book ${_selectedIds.length} gig${_selectedIds.length == 1 ? '' : 's'}'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMyGigsTab(ShiftListState state) {
    if (state.isLoading && state.myShifts.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.myShifts.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(shiftListProvider.notifier).refresh());
    }
    if (state.myShifts.isEmpty) {
      return const EmptyView(
        title: 'No gigs booked',
        message: "You haven't booked any gigs yet — check the Available tab.",
        icon: Icons.event_busy_outlined,
      );
    }

    final grouped = groupShiftsBySession(state.myShifts);

    return RefreshIndicator(
      onRefresh: () => ref.read(shiftListProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in grouped.entries) ...[
            GigSessionCard(
              session: entry.key,
              shifts: entry.value,
              trailingBuilder: (shift) => TextButton(
                onPressed: _cancellingId == shift.id ? null : () => _cancel(shift.id),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: _cancellingId == shift.id
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _AvailableTrailing extends StatelessWidget {
  final ShiftModel shift;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _AvailableTrailing({required this.shift, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (shift.isFull && !selected) {
      return Text('Full', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600));
    }
    return Checkbox(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
      activeColor: AppColors.textPrimary,
    );
  }
}
