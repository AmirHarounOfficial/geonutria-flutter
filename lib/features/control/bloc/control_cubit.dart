import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../data/control_models.dart';
import '../data/control_repository.dart';

class ControlState extends Equatable {
  const ControlState({
    this.state = LoadState.initial,
    this.actuators = const [],
    this.liveStates = const {},
    this.schedules = const [],
    this.sensorDevices = const [],
    this.error,
  });

  final LoadState state;
  final List<Actuator> actuators;

  /// Live state per actuator id, refreshed on a timer.
  final Map<int, ActuatorLiveState> liveStates;

  final List<Schedule> schedules;

  /// Devices that can act as a threshold source, loaded lazily when the
  /// schedule builder is opened.
  final List<SensorDevice> sensorDevices;

  final String? error;

  bool isOn(int actuatorId) => liveStates[actuatorId]?.isOn ?? false;

  ControlState copyWith({
    LoadState? state,
    List<Actuator>? actuators,
    Map<int, ActuatorLiveState>? liveStates,
    List<Schedule>? schedules,
    List<SensorDevice>? sensorDevices,
    String? error,
  }) => ControlState(
    state: state ?? this.state,
    actuators: actuators ?? this.actuators,
    liveStates: liveStates ?? this.liveStates,
    schedules: schedules ?? this.schedules,
    sensorDevices: sensorDevices ?? this.sensorDevices,
    error: error,
  );

  @override
  List<Object?> get props => [
    state,
    actuators,
    liveStates,
    schedules,
    sensorDevices,
    error,
  ];
}

/// Owns actuators and automation schedules from the `/control` router.
///
/// Timings mirror the web dashboard so both clients behave the same: states
/// poll every 5 seconds, and after a command the state is re-read quickly
/// (the device usually reports back within a moment) followed by the actuator
/// list, which carries the server's own optimistic state update.
class ControlCubit extends Cubit<ControlState> {
  ControlCubit(this._repo) : super(const ControlState());

  final ControlRepository _repo;

  static const _pollInterval = Duration(seconds: 5);
  static const _afterCommandState = Duration(milliseconds: 500);
  static const _afterCommandList = Duration(seconds: 1);

  Timer? _poll;

  Future<void> load() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final results = await Future.wait([
        _repo.actuators(),
        _repo.actuatorStates(),
        _repo.schedules(),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          state: LoadState.loaded,
          actuators: results[0] as List<Actuator>,
          liveStates: results[1] as Map<int, ActuatorLiveState>,
          schedules: results[2] as List<Schedule>,
        ),
      );
      _startPolling();
    } on AppException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(state: LoadState.error, error: e.message));
      }
    }
  }

  void _startPolling() {
    if (_poll != null || state.actuators.isEmpty) return;
    _poll = Timer.periodic(_pollInterval, (_) => refreshStates());
  }

  /// Failures are swallowed: this runs on a timer, and a transient blip must
  /// not raise an error banner or stop the polling.
  Future<void> refreshStates() async {
    if (isClosed) return;
    try {
      final states = await _repo.actuatorStates();
      if (!isClosed) emit(state.copyWith(liveStates: states));
    } on AppException {
      // ignored on purpose — see doc comment
    }
  }

  Future<void> refreshActuators() async {
    if (isClosed) return;
    try {
      final list = await _repo.actuators();
      if (!isClosed) emit(state.copyWith(actuators: list));
    } on AppException {
      // ignored — the list is refreshed again on the next load
    }
  }

  /// Sends a command and schedules the two follow-up reads. Rethrows so the
  /// tile can revert its optimistic position and show the reason.
  Future<void> command(
    int actuatorId, {
    required String action,
    Object? value,
    int? durationMinutes,
  }) async {
    await _repo.command(
      actuatorId,
      action: action,
      value: value,
      durationMinutes: durationMinutes,
    );
    Future.delayed(_afterCommandState, refreshStates);
    Future.delayed(_afterCommandList, refreshActuators);
  }

  // ── Schedules ──────────────────────────────────────────────────────────
  Future<void> loadSchedules() async {
    try {
      final list = await _repo.schedules();
      if (!isClosed) emit(state.copyWith(schedules: list));
    } on AppException catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    }
  }

  Future<bool> saveSchedule(Schedule s) async {
    try {
      if (s.id == null) {
        await _repo.createSchedule(s);
      } else {
        await _repo.updateSchedule(s.id!, s);
      }
      await loadSchedules();
      return true;
    } on AppException catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
      return false;
    }
  }

  Future<void> toggleSchedule(int id) async {
    // Reflect the flip straight away, then reconcile with the server, which
    // owns the resulting value.
    emit(
      state.copyWith(
        schedules: [
          for (final s in state.schedules)
            if (s.id == id) s.copyWith(isActive: !s.isActive) else s,
        ],
      ),
    );
    try {
      await _repo.toggleSchedule(id);
      await loadSchedules();
    } on AppException catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
      await loadSchedules();
    }
  }

  Future<void> deleteSchedule(int id) async {
    try {
      await _repo.deleteSchedule(id);
      await loadSchedules();
    } on AppException catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
    }
  }

  /// Loaded on demand — only the schedule builder needs it.
  Future<void> loadSensorDevices() async {
    if (state.sensorDevices.isNotEmpty) return;
    try {
      final list = await _repo.sensorDevices();
      if (!isClosed) emit(state.copyWith(sensorDevices: list));
    } on AppException {
      // The builder falls back to "no source available".
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
