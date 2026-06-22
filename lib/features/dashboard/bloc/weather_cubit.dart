import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/iot_models.dart';
import '../data/iot_repository.dart';
import 'history_cubit.dart' show LoadState;

class WeatherState extends Equatable {
  const WeatherState({
    this.state = LoadState.initial,
    this.interval = 'Days',
    this.points = const [],
    this.error,
  });

  final LoadState state;
  final String interval;
  final List<WeatherPoint> points;
  final String? error;

  static const intervals = ['Days', 'Weeks', 'Months'];

  WeatherState copyWith({
    LoadState? state,
    String? interval,
    List<WeatherPoint>? points,
    String? error,
  }) =>
      WeatherState(
        state: state ?? this.state,
        interval: interval ?? this.interval,
        points: points ?? this.points,
        error: error,
      );

  @override
  List<Object?> get props => [state, interval, points, error];
}

/// Loads macro-weather (Open-Meteo-sourced) history + forecast. Free endpoint.
class WeatherCubit extends Cubit<WeatherState> {
  WeatherCubit(this._repo) : super(const WeatherState());

  final IotRepository _repo;

  Future<void> load(int deviceId, {String? interval}) async {
    final iv = interval ?? state.interval;
    emit(state.copyWith(state: LoadState.loading, interval: iv, error: null));
    try {
      final pts = await _repo.getWeatherCharts(deviceId, interval: iv);
      emit(state.copyWith(state: LoadState.loaded, points: pts));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }
}
