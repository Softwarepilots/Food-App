import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/shift_remote_datasource.dart';
import '../../data/models/shift_model.dart';

final shiftRemoteDataSourceProvider = Provider<ShiftRemoteDataSource>((ref) {
  return ShiftRemoteDataSource(ref.watch(dioProvider));
});

class ShiftListState extends Equatable {
  final List<ShiftModel> availableShifts;
  final List<ShiftModel> myShifts;
  final bool isLoading;
  final Failure? failure;

  const ShiftListState({this.availableShifts = const [], this.myShifts = const [], this.isLoading = false, this.failure});

  ShiftListState copyWith({
    List<ShiftModel>? availableShifts,
    List<ShiftModel>? myShifts,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ShiftListState(
      availableShifts: availableShifts ?? this.availableShifts,
      myShifts: myShifts ?? this.myShifts,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [availableShifts, myShifts, isLoading, failure];
}

/// Available gigs and the rider's own booked gigs are two different backend
/// endpoints, but one screen (two tabs) shows both and a book/cancel on
/// either tab has to be reflected on the other immediately — so one notifier
/// owns both lists rather than syncing two separate providers.
class ShiftListNotifier extends Notifier<ShiftListState> {
  @override
  ShiftListState build() {
    Future.microtask(refresh);
    return const ShiftListState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final dataSource = ref.read(shiftRemoteDataSourceProvider);
      final results = await Future.wait([dataSource.getUpcomingShifts(), dataSource.getMyShifts()]);
      state = state.copyWith(
        availableShifts: results[0].items,
        myShifts: results[1].items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> book(String shiftId) async {
    await ref.read(shiftRemoteDataSourceProvider).bookShift(shiftId);
    await refresh();
  }

  /// Books several selected gigs one at a time (there's no bulk endpoint) —
  /// if one fails partway (e.g. it filled up while the rider was deciding),
  /// the already-booked ones stay booked rather than the whole selection
  /// rolling back, and the error surfaces so the caller can tell the rider
  /// which one didn't go through.
  Future<void> bookMultiple(Iterable<String> shiftIds) async {
    for (final id in shiftIds) {
      await ref.read(shiftRemoteDataSourceProvider).bookShift(id);
    }
    await refresh();
  }

  Future<void> cancel(String shiftId) async {
    await ref.read(shiftRemoteDataSourceProvider).cancelShift(shiftId);
    await refresh();
  }
}

final shiftListProvider = NotifierProvider<ShiftListNotifier, ShiftListState>(ShiftListNotifier.new);
