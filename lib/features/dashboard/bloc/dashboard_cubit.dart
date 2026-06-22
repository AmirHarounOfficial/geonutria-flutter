import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../data/iot_models.dart';
import '../data/iot_repository.dart';

enum DashStatus { initial, loadingDevices, ready, error }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashStatus.initial,
    this.devices = const [],
    this.selectedId,
    this.iot,
    this.statusLoading = false,
    this.error,
  });

  final DashStatus status;
  final List<Device> devices;
  final int? selectedId;
  final IotStatus? iot;
  final bool statusLoading;
  final String? error;

  Device? get selectedDevice {
    for (final d in devices) {
      if (d.id == selectedId) return d;
    }
    return null;
  }

  DashboardState copyWith({
    DashStatus? status,
    List<Device>? devices,
    int? selectedId,
    IotStatus? iot,
    bool? statusLoading,
    String? error,
    bool clearIot = false,
  }) =>
      DashboardState(
        status: status ?? this.status,
        devices: devices ?? this.devices,
        selectedId: selectedId ?? this.selectedId,
        iot: clearIot ? null : (iot ?? this.iot),
        statusLoading: statusLoading ?? this.statusLoading,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, devices, selectedId, iot, statusLoading, error];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repo, this._auth) : super(const DashboardState());

  final IotRepository _repo;
  final AuthCubit _auth;

  Future<void> loadDevices() async {
    emit(state.copyWith(status: DashStatus.loadingDevices, error: null));
    try {
      final devices = await _repo.getDevices();
      if (devices.isEmpty) {
        emit(state.copyWith(status: DashStatus.ready, devices: const []));
        return;
      }
      final selected = state.selectedId ?? devices.first.id;
      emit(state.copyWith(
        status: DashStatus.ready,
        devices: devices,
        selectedId: selected,
      ));
      await loadStatus();
    } on AppException catch (e) {
      emit(state.copyWith(status: DashStatus.error, error: e.message));
    }
  }

  void selectDevice(int id) {
    if (id == state.selectedId) return;
    emit(state.copyWith(selectedId: id, clearIot: true));
    loadStatus();
  }

  /// Loads live status for the selected device (costs 5 credits).
  Future<void> loadStatus() async {
    final id = state.selectedId;
    if (id == null) return;
    emit(state.copyWith(statusLoading: true, error: null));
    try {
      final iot = await _repo.getStatus(id);
      emit(state.copyWith(statusLoading: false, iot: iot));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(statusLoading: false)); // paywall handled globally
    } on AppException catch (e) {
      emit(state.copyWith(statusLoading: false, error: e.message));
    }
  }

  /// Manual refresh (costs 1 credit), then reloads status.
  Future<void> refresh() async {
    final id = state.selectedId;
    if (id == null) return;
    emit(state.copyWith(statusLoading: true, error: null));
    try {
      await _repo.refresh(id);
      _auth.onCreditsSpent(1);
      await loadStatus();
    } on InsufficientCreditsException {
      emit(state.copyWith(statusLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(statusLoading: false, error: e.message));
    }
  }
}
