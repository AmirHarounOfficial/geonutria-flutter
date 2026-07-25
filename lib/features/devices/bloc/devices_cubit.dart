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
    this.error,
  });

  final LoadState state;
  final List<MyDevice> devices;
  final String? error;

  DevicesState copyWith({
    LoadState? state,
    List<MyDevice>? devices,
    String? error,
  }) => DevicesState(
    state: state ?? this.state,
    devices: devices ?? this.devices,
    error: error,
  );

  @override
  List<Object?> get props => [state, devices, error];
}

class DevicesCubit extends Cubit<DevicesState> {
  DevicesCubit(this._repo) : super(const DevicesState());

  final DevicesRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final devices = await _repo.list();
      emit(state.copyWith(state: LoadState.loaded, devices: devices));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
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
  Future<void> publish(int deviceId, String topic, String payload) =>
      _repo.publish(deviceId, topic, payload);

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
