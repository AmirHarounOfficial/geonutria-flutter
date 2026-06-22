import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../data/assets_repository.dart';

class AssetsState extends Equatable {
  const AssetsState({
    this.state = LoadState.initial,
    this.farms = const [],
    this.error,
  });

  final LoadState state;
  final List<Farm> farms;
  final String? error;

  AssetsState copyWith({LoadState? state, List<Farm>? farms, String? error}) =>
      AssetsState(
        state: state ?? this.state,
        farms: farms ?? this.farms,
        error: error,
      );

  @override
  List<Object?> get props => [state, farms, error];
}

class AssetsCubit extends Cubit<AssetsState> {
  AssetsCubit(this._repo) : super(const AssetsState());

  final AssetsRepository _repo;

  Future<void> loadFarms() async {
    emit(state.copyWith(state: LoadState.loading, error: null));
    try {
      final farms = await _repo.getFarms();
      emit(state.copyWith(state: LoadState.loaded, farms: farms));
    } on AppException catch (e) {
      emit(state.copyWith(state: LoadState.error, error: e.message));
    }
  }

  Future<void> createFarm({
    required String name,
    required String address,
    required double area,
    double? lat,
    double? lon,
  }) async {
    await _repo.createFarm(
        name: name, address: address, totalArea: area, latitude: lat, longitude: lon);
    await loadFarms();
  }

  Future<void> deleteFarm(int id) async {
    await _repo.deleteFarm(id);
    await loadFarms();
  }

  // Crops / trees are loaded on demand by the detail screens.
  AssetsRepository get repo => _repo;
}
