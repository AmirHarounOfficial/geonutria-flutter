import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../data/device_models.dart';
import '../data/devices_repository.dart';

class DevicesState extends Equatable {
  const DevicesState({
    this.state = LoadState.initial,
    this.devices = const [],
    this.controlStates = const {},
    this.error,
  });

  final LoadState state;
  final List<MyDevice> devices;

  /// Last payload reported on each control's state topic, keyed by topic.
  final Map<String, String> controlStates;

  final String? error;

  DevicesState copyWith({
    LoadState? state,
    List<MyDevice>? devices,
    Map<String, String>? controlStates,
    String? error,
  }) => DevicesState(
    state: state ?? this.state,
    devices: devices ?? this.devices,
    controlStates: controlStates ?? this.controlStates,
    error: error,
  );

  @override
  List<Object?> get props => [state, devices, controlStates, error];
}

class DevicesCubit extends Cubit<DevicesState> {
  DevicesCubit(this._repo) : super(const DevicesState());

  final DevicesRepository _repo;

  static const _statePollInterval = Duration(seconds: 5);
  Timer? _statePoll;

  bool get _anyStateFeedback =>
      state.devices.any((d) => d.controls.any((c) => c.hasStateFeedback));

  Future<void> load() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final devices = await _repo.list();
      emit(state.copyWith(state: LoadState.loaded, devices: devices));
      _syncStatePolling();
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }

  /// Polls only while at least one control declares a state topic, so users
  /// who haven't configured feedback pay no request cost.
  void _syncStatePolling() {
    if (_anyStateFeedback) {
      if (_statePoll == null) {
        _statePoll = Timer.periodic(_statePollInterval, (_) => refreshStates());
        refreshStates();
      }
    } else {
      _statePoll?.cancel();
      _statePoll = null;
    }
  }

  /// Pulls the devices' reported control states. Failures are ignored: this
  /// runs on a timer and a transient network blip must not surface an error
  /// banner or stop the polling.
  Future<void> refreshStates() async {
    if (isClosed) return;
    try {
      final states = await _repo.controlStates();
      if (!isClosed) emit(state.copyWith(controlStates: states));
    } on AppException {
      // ignored on purpose — see doc comment
    }
  }

  @override
  Future<void> close() {
    _statePoll?.cancel();
    return super.close();
  }

  Future<bool> bind({
    required String name,
    required List<String> mqttTopics,
    List<ControlEndpoint> controls = const [],
    String? otaTopic,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _repo.bind(
        name: name,
        mqttTopics: mqttTopics,
        controls: controls,
        otaTopic: otaTopic,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );
      await load();
      return true;
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
      return false;
    }
  }

  Future<bool> update(
    int deviceId, {
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? mqttTopics,
    List<ControlEndpoint>? controls,
    String? otaTopic,
  }) async {
    try {
      await _repo.update(
        deviceId,
        name: name,
        location: location,
        latitude: latitude,
        longitude: longitude,
        mqttTopics: mqttTopics,
        controls: controls,
        otaTopic: otaTopic,
      );
      await load();
      return true;
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
      return false;
    }
  }

  Future<void> unbind(int deviceId) async {
    try {
      await _repo.unbind(deviceId);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// Publish a control command; throws [AppException] so the UI can show the
  /// exact broker/permission error inline.
  Future<void> publish(int deviceId, String topic, String payload) async {
    await _repo.publish(deviceId, topic, payload);
    // Devices report back on their state topic a moment after acting; check
    // early instead of waiting out the full poll interval.
    Future.delayed(const Duration(milliseconds: 800), refreshStates);
  }

  Future<String> pushFirmware(
    int deviceId, {
    required List<int> bytes,
    required String fileName,
    required String version,
    String? otaTopic,
  }) async {
    final v = await _repo.pushFirmware(
      deviceId,
      bytes: bytes,
      fileName: fileName,
      version: version,
      otaTopic: otaTopic,
    );
    await load();
    return v;
  }
}
