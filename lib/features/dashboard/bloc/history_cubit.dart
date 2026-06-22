import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../data/iot_models.dart';
import '../data/iot_repository.dart';

enum LoadState { initial, loading, loaded, error }

class HistoryState extends Equatable {
  const HistoryState({
    this.state = LoadState.initial,
    this.interval = 'Live',
    this.points = const [],
    this.error,
  });

  final LoadState state;
  final String interval;
  final List<HistoryPoint> points;
  final String? error;

  static const intervals = ['Live', 'Hours', 'Days', 'Weeks', 'Months', 'Years'];

  HistoryState copyWith({
    LoadState? state,
    String? interval,
    List<HistoryPoint>? points,
    String? error,
  }) =>
      HistoryState(
        state: state ?? this.state,
        interval: interval ?? this.interval,
        points: points ?? this.points,
        error: error,
      );

  @override
  List<Object?> get props => [state, interval, points, error];
}

/// Loads historical readings for a device at a chosen interval (costs 5 credits
/// per load).
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repo, this._auth) : super(const HistoryState());

  final IotRepository _repo;
  final AuthCubit _auth;

  Future<void> load(int deviceId, {String? interval}) async {
    final iv = interval ?? state.interval;
    emit(state.copyWith(state: LoadState.loading, interval: iv, error: null));
    try {
      final pts = await _repo.getHistory(deviceId,
          interval: iv, limit: iv == 'Live' ? 50 : 30);
      emit(state.copyWith(state: LoadState.loaded, points: pts));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(state: LoadState.error, error: 'Insufficient credits'));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }
}
